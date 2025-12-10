//
//  MediaView.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/07/25.
//


import SwiftUI
import AVKit
import QuickLookThumbnailing
import RealmSwift
import QuickLook
import SDWebImageSwiftUI

enum MediaType: String, PersistableEnum {
    case image = "m.image"
    case document = "m.file"
    case video = "m.video"
    case audio = "m.audio"
    case gif = "m.gif"
}

final class MediaLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var localURL: URL?
    @Published var progress: Double = 0
    @Published var error: Error? = nil

    func load(remoteURL: String, type: MediaType, localURL: URL? = nil) {
        if let localURL {
            DispatchQueue.main.async {
                self.localURL = localURL
                self.preparePreviewIfNeeded(for: type, from: localURL)
            }
        }
        
        if remoteURL.isEmpty { return }
        
        MediaCacheManager.shared.getMedia(
            url: remoteURL,
            type: type,
            progressHandler: { [weak self] p in
                DispatchQueue.main.async { self?.progress = p }
            },
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let pathString):
                    let url = pathString.hasPrefix("file://")
                        ? URL(string: pathString)!
                        : URL(fileURLWithPath: pathString)

                    DispatchQueue.main.async {
                        self.localURL = url
                        self.progress = 1.0
                    }
                    // Only decode images as UIImage. Never attempt for video/audio/pdf.
                    DispatchQueue.global(qos: .userInitiated).async {
                        switch type {
                        case .image, .gif:
                            // If it's truly an image or gif, try to decode a bitmap
                            // Only attempt bitmap decode for real images (or gifs)
                            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                                guard let self = self else { return }
                                let target: CGFloat = 640
                                if let img = MediaDecodeHelper.downsampleCached(url: url, maxPixel: target) {
                                    MediaDecodeHelper.setWithoutAnimation { self.image = img }
                                } else {
                                    MediaDecodeHelper.setWithoutAnimation { self.image = nil }
                                }
                            }

                        case .video:
                            // Generate a thumbnail (or rely on server /thumbnail)
                            generateVideoThumbnailAsync(from: url) { result in
                                switch result {
                                case .success(let image):
                                    self.image = image
                                case .failure: break
                                }
                            }

                        case .document, .audio:
                            // Prepare a generic preview thumbnail (QuickLook)
                            generateDocumentThumbnailAsync(from: url) { result in
                                switch result {
                                case .success(let image):
                                    self.image = image
                                case .failure: break
                                }
                            }
                        }
                    }

                case .failure(let err):
                    DispatchQueue.main.async { self.error = err }
                }
            }
        )
    }
    
    private func preparePreviewIfNeeded(for type: MediaType, from url: URL) {
        previewImage(for: type, url: url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let ui):
                self.image = ui
            case .failure(let err):
                self.error = err
            }
        }
    }
}

struct MediaView<Placeholder: View, ErrorView: View>: View {
    let mediaURL: String
    let userName: String?
    let timeText: String?
    let mediaType: MediaType
    let placeholder: Placeholder
    let errorView: ErrorView
    let isSender: Bool
    let downloadedImage: UIImage?
    let senderImage: String
    var localURLOverride: URL? = nil
    var externalProgress: Double? = nil
    var isUploading: Bool = false
    
    @StateObject private var loader = MediaLoader()
    @State private var showFullScreen = false
    @State private var thumbnail: UIImage?
    @State private var stickyProgress: Double = 0
    @State private var finishedOnce = false
    @State private var isVisible = false
    @State private var lastProgress: Double = 0
    @State private var playGIF = false
    
    private var displayedProgress: Double {
        let live = clamp((externalProgress ?? loader.progress), min: 0, max: 1)
        // when off-screen, freeze to the last known value to avoid churn
        return max(stickyProgress, isVisible ? live : lastProgress)
    }
    
    var body: some View {
        ZStack {
            switch mediaType {
            case .image:
                if let img = loader.image {
                    let aspectRatio = img.size.width / img.size.height
                    let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio)
                    
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayWidth / aspectRatio)
                        .onTapGesture { showFullScreen = true }
                        .fullScreenCover(isPresented: $showFullScreen) {
                            FullScreenImageView(
                                source: .uiImage(img),
                                userName: userName ?? "",
                                timeText: timeText ?? "",
                                isPresented: $showFullScreen
                            )
                        }
                } else if loader.progress > 0 && loader.progress < 1 {
                    placeholder
                } else if loader.error != nil {
                    errorView
                } else {
                    placeholder
                }
            
            case .gif:
                if let localURL = loader.localURL?.absoluteString, let fileURL = URL(string: localURL) {
                    let gifURL = URL(fileURLWithPath: fileURL.path)
                    Group {
                        if playGIF {
                            // Animate only when the user taps
                            AnimatedImage(url: gifURL)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220)
                                .clipped()
                        } else {
                            // Static first frame while scrolling (cheap to render)
                            WebImage(
                                url: gifURL,
                                options: [.decodeFirstFrameOnly, .scaleDownLargeImages],
                                context: [.imageThumbnailPixelSize : CGSize(width: 440, height: 430)] // ~2x of display
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220)
                            .clipped()
                            .onTapGesture { playGIF = true }
                        }
                    }
                } else {
                    placeholder
                }

            case .video:
                if let url = loader.localURL {
                    ZStack {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb).resizable().scaledToFit()
                        } else {
                            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 200)
                        }
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50)).foregroundColor(.white)
                    }
                    .onAppear {
                        if thumbnail == nil { generateVideoThumbnail(for: url) }
                    }
                    .onTapGesture { showFullScreen = true }
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenImageView(
                            source: .uiImage(UIImage()),
                            userName: userName ?? "",
                            timeText: timeText ?? "",
                            mediaType: .video,
                            mediaUrl: url.path,          // pass path, not raw string
                            isPresented: $showFullScreen
                        )
                    }
                } else if loader.progress > 0 && loader.progress < 1 {
                    placeholder
                } else if loader.error != nil {
                    errorView
                } else {
                    placeholder
                }

            case .document:
                if let url = loader.localURL {
                    DocumentMessageRow(
                        fileURL: url,
                        fileName: url.lastPathComponent,
                        pageCountText: "0",
                        fileSizeText: ""
                    )
                } else if loader.progress > 0 && loader.progress < 1 {
                    placeholder
                } else if loader.error != nil {
                    errorView
                } else {
                    placeholder
                }

            case .audio:
                if let url = loader.localURL {
                    AudioMessageRow(
                        avatar: downloadedImage ?? UIImage(),
                        fileURL: url,
                        isSender: isSender,
                        senderImage: senderImage,
                        senderName: userName ?? ""
                    )
                } else if loader.progress > 0 && loader.progress < 1 {
                    placeholder
                } else if loader.error != nil {
                    errorView
                } else {
                    placeholder
                }
            }
        }
        .overlay(progressOverlay, alignment: .bottom)
        .onAppear {
            isVisible = true
            // show latest known value immediately when appearing
            stickyProgress = max(stickyProgress, lastProgress)
            
            if loader.localURL == nil && loader.image == nil {
                if let local = localURLOverride {
                    loader.load(remoteURL: mediaURL, type: mediaType, localURL: local)
                } else if !mediaURL.isEmpty {
                    loader.load(remoteURL: mediaURL, type: mediaType, localURL: nil)
                }
            }
        }
        .onDisappear {
            isVisible = false
        }
        .onReceive(
            loader.$progress
                .map { MediaDecodeHelper.quantizeProgress($0, steps: 20) } // 5% steps
                .removeDuplicates()
                .throttle(for: .milliseconds(250), scheduler: RunLoop.main, latest: true)
        ) { p in
            lastProgress = p
            if isVisible {
                stickyProgress = max(stickyProgress, p)
                if p >= 0.999 { finishedOnce = true }
            }
        }
        .animation(nil, value: displayedProgress)
        .onChange(of: externalProgress) { v in
            let p = clamp(v ?? 0, min: 0, max: 1)
            lastProgress = p
            if isVisible {
                stickyProgress = max(stickyProgress, p)
                if p >= 0.999 { finishedOnce = true }
            }
        }
    }
    
    // MARK: - Helper: Calculate Display Width
    private func calculateDisplayWidth(aspectRatio: CGFloat) -> CGFloat {
        let targetHeight: CGFloat = 240
        let maxWidth: CGFloat = 320
        let minWidth: CGFloat = 150
        let calculatedWidth = targetHeight * aspectRatio
        return min(maxWidth, max(minWidth, calculatedWidth))
    }
    private var progressOverlay: some View {
        let p = displayedProgress
        // show only while actively moving between (0,1)
        let shouldShow = !finishedOnce && p > 0 && p < 1
        return Group {
            if shouldShow {
                VStack(spacing: 0) {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.6))
                        .transaction { $0.animation = nil }
                }
                .transition(.opacity)
            }
        }
    }
    
    private func clamp(_ v: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, v))
    }
    
    private func generateVideoThumbnail(for url: URL) {
        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let t = CMTime(seconds: 1, preferredTimescale: 60)
        DispatchQueue.global().async {
            if let cg = try? gen.copyCGImage(at: t, actualTime: nil) {
                DispatchQueue.main.async { thumbnail = UIImage(cgImage: cg) }
            }
        }
    }
}

// MARK: - Extension for default placeholder/error

extension MediaView where Placeholder == Image, ErrorView == Image {
    init(
        mediaURL: String,
        mediaType: MediaType,
        time: String,
        userName: String,
        isSender: Bool,
        downloadedImage: UIImage,
        senderImage: String,
        localURLOverride: URL? = nil,
        externalProgress: Double? = nil,
        isUploading: Bool = false
    ) {
        self.init(
            mediaURL: mediaURL,
            userName: userName,
            timeText: time,
            mediaType: mediaType,
            placeholder: Image(systemName: "photo"),
            errorView: Image(systemName: "exclamationmark.triangle"),
            isSender: isSender,
            downloadedImage: downloadedImage,
            senderImage: senderImage
        )
        self.localURLOverride = localURLOverride
        self.externalProgress = externalProgress
        self.isUploading = isUploading
    }
}


import SwiftUI
import AVFoundation

// MARK: - Voice message bubble

struct VoiceMessageBubble: View {
    var receiverAvatar: Image
    var current: String = "00:00"
    var total: String = "0:06"
    var isPlaying: Bool = false
    var isSender: Bool = false
    var playbackRate: Float = 1.0
    var onTapPlay: () -> Void = {}
    var onTapRate: () -> Void = {}
    var senderImage: String = ""
    var senderInitial: String = ""
    var backgroundColor: Color = .clear

    var body: some View {
        HStack(spacing: 8) {
            
            if isSender {
                if isPlaying {
                    Button(action: onTapRate) {
                        Text("\(Int(playbackRate))x")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(8)
                } else {
                    ZStack {
                        if let url = URL(string: senderImage) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 48, height: 48)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                case .failure(_):
                                    initialsView
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            initialsView
                        }
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Image("micButton")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                }
                Button(action: onTapPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Image("Component 27 white")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                
                Text(current)
                    .font(Design.Font.regular(10))
                    .foregroundColor(.white)
                    .frame(minWidth: 40)

            } else {
               
                
                Button(action: onTapPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                Image("Component 27")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                
                Text(current)
                    .font(Design.Font.regular(10))
                    .foregroundColor(.black)
                    .frame(minWidth: 40)
                
                if isPlaying {
                    Button(action: onTapRate) {
                        Text("\(Int(playbackRate))x")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 20)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                } else {
                    ZStack {
                        if receiverAvatar != Image(uiImage: UIImage()) {
                            receiverAvatar
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            initialsView
                        }
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Image("micButton")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                        }
                        
                    }
                   
                }
            }
            
        }
        .frame(maxWidth: .infinity, alignment: isSender ? .trailing : .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var initialsView: some View {
        Text(senderInitial)
            .font(Design.Font.bold(16))
            .frame(width: 48, height: 48)
            .background(backgroundColor)
            .foregroundColor(Design.Color.primaryText.opacity(0.7))
            .clipShape(Circle())
    }

}


// MARK: - Document message bubble

struct DocumentMessageBubble: View {
    var thumbnail: Image? = nil     // pass a preview if you have one
    var fileName: String
    var metaTop: String = "PDF"
    var metaMid: String = "Page count"
    var metaBot: String = "Size"
    var time: String = "00:00"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // bottom card
                HStack(alignment: .center, spacing: 8) {
                    ZStack {
                        Image(systemName: "doc.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(Design.Font.regular(12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(metaTop)
                            Text("•")
                            Text(metaMid)
                            Text("•")
                            Text(metaBot)
                        }
                        .font(Design.Font.regular(8))
                        .foregroundColor(Design.Color.grayText)
                        .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Helpers

extension UIImage {
    convenience init(color: UIColor, size: CGSize = .init(width: 2, height: 2)) {
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        color.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        self.init(cgImage: img.cgImage!)
    }
}

import SwiftUI
import AVFoundation

final class AudioBubblePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var current: TimeInterval = 0
    @Published var total: TimeInterval = 0
    @Published var playbackRate: Float = 1.0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()
        do {
            let data = try Data(contentsOf: url)
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.enableRate = true
            total = player?.duration ?? 0
            current = 0
        } catch {
            print("Audio load error:", error)
        }
    }

    func toggle() {
        guard let p = player else { return }
        if p.isPlaying { pause() } else { play() }
    }

    func playThroughSpeaker() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to set audio session:", error)
        }
    }
    
    
    func play() {
        guard let p = player else { return }
        playThroughSpeaker()
        p.rate = playbackRate
        p.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        current = 0
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.current = p.currentTime
            self.total = p.duration
            if p.currentTime >= p.duration { self.stop() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
    
    func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        if let p = player, p.isPlaying {
            p.rate = rate
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

    static func mmss(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct AudioMessageRow: View {
    let avatar: UIImage
    let fileURL: URL
    let isSender: Bool
    let senderImage: String
    let senderName: String

    @StateObject private var vm = AudioBubblePlayer()
    private let speeds: [Float] = [1.0, 2.0, 3.0, 4.0]

    var body: some View {
        VoiceMessageBubble(
            receiverAvatar: Image(uiImage: avatar),
            current: AudioBubblePlayer.mmss(vm.current),
            total: AudioBubblePlayer.mmss(vm.total),
            isPlaying: vm.isPlaying,
            isSender: isSender,
            playbackRate: vm.playbackRate,
            onTapPlay: { vm.toggle() },
            onTapRate: {
                let currentIndex = speeds.firstIndex(of: vm.playbackRate) ?? 0
                let nextIndex = (currentIndex + 1) % speeds.count
                vm.setPlaybackRate(speeds[nextIndex])
            },
            senderImage: senderImage,
            senderInitial: getInitials(from: senderName),
            backgroundColor: randomBackgroundColor()
        )
        .onAppear { vm.load(url: fileURL) }
    }
}

struct DocumentMessageRow: View {
    let fileURL: URL
    let fileName: String
    let pageCountText: String
    let fileSizeText: String
    @State private var showQL = false

    var body: some View {
        DocumentMessageBubble(
            thumbnail: nil, // or Image(uiImage: yourThumb)
            fileName: fileName,
            metaTop: fileURL.pathExtension.uppercased(),
            metaMid: pageCountText,
            metaBot: fileSizeText,
            time: "00:00"
        )
        .contentShape(Rectangle())
        .onTapGesture { showQL = true }         // tap anywhere opens
        .sheet(isPresented: $showQL) {
            QuickLookPreview(url: fileURL)
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }
    func updateUIViewController(_ vc: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: QLPreviewItemWrapper
        init(url: URL) { self.item = QLPreviewItemWrapper(url: url) }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { item }
    }
    final class QLPreviewItemWrapper: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        init(url: URL) { self.previewItemURL = url }
    }
}
