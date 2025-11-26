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
    
    @State private var progress: Double = 0
    @State private var localURL: String?
    @State private var error: Error?
    @State private var thumbnail: UIImage?
    @State private var showFullScreen = false
    
    var body: some View {
        ZStack {
            if let url = localURL {
                switch mediaType {
                case .image:
                    let fileURL: URL = url.hasPrefix("file://") ? URL(string: url)! : URL(fileURLWithPath: url)
                    if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                        // fallback if the path form fails for some reason
                        guard let data = try? Data(contentsOf: fileURL) else { return nil }
                        return UIImage(data: data)
                    }() {
                        // Optional: pre-decompress for smoother UI on iOS 15+
                        let finalImage = uiImage.preparingForDisplay() ?? uiImage
                        Image(uiImage: finalImage)
                            .resizable()
                            .scaledToFit()
                            .onTapGesture {
                                showFullScreen = true
                            }
                            .fullScreenCover(isPresented: $showFullScreen) {
                                FullScreenImageView(
                                    source: .uiImage(finalImage),
                                    userName: userName ?? "",
                                    timeText: timeText ?? "",
                                    isPresented: $showFullScreen
                                )
                            }
                    } else {
                        placeholder
                    }
                    
                case .video:
                    
                    if FileManager.default.fileExists(atPath: url) {
                        let videoURL = URL(fileURLWithPath: url)
                        ZStack {
                            if let thumb = thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Rectangle()
                                    .fill(Color.black.opacity(0.1))
                                    .frame(height: 200)
                            }
                            
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }.onAppear {
                            if thumbnail == nil {
                                generateVideoThumbnail(for: videoURL)
                            }
                        }
                        .onTapGesture {
                            showFullScreen = true
                        }
                        .fullScreenCover(isPresented: $showFullScreen) {
                            FullScreenImageView(
                                source: .uiImage(UIImage()),
                                userName: userName ?? "",
                                timeText: timeText ?? "",
                                mediaType: .video,
                                mediaUrl: url,
                                isPresented: $showFullScreen
                            )
                        }
                    } else {
                        Text("Video file not found")
                    }
                    
                case .document:
                    let docURL = url.hasPrefix("file://") ? URL(string: url)! : URL(fileURLWithPath: url)
                       DocumentMessageRow(
                           fileURL: docURL,
                           fileName: docURL.lastPathComponent,
                           pageCountText: "0",   // compute if you want
                           fileSizeText: ""
                       )
                case .audio:
                    if FileManager.default.fileExists(atPath: url) {
                        AudioMessageRow(avatar: downloadedImage ?? UIImage(), fileURL: URL(fileURLWithPath: url), isSender: isSender, senderImage: senderImage, senderName: userName ?? "")
                      } else {
                          Text("Audio not found")
                      }
                case .gif:
                    let gifURL = URL(fileURLWithPath: url)
                    WebImage(url: gifURL)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .clipped()
                }
            } else if progress > 0 && progress < 1 {
                VStack(spacing: 8) {
                    placeholder
                }
            } else if error != nil {
                placeholder
            } else {
                placeholder
            }
        }
        .onAppear {
            MediaCacheManager.shared.getMedia(
                url: mediaURL,
                type: mediaType,
                progressHandler: { prog in
                    progress = prog
                },
                completion: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let imagePath):
                            DispatchQueue.main.async {
                                localURL = imagePath
                            }
                        case .failure(let err):
                            self.error = err
                        }
                    }
                }
            )
        }
    }
    
    private func generateVideoThumbnail(for url: URL) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        DispatchQueue.global().async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.thumbnail = uiImage
                }
            } catch {
                print("Thumbnail generation failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Extension for default placeholder/error

extension MediaView where Placeholder == Image, ErrorView == Image {
    init(mediaURL: String, mediaType: MediaType, time: String, userName: String, isSender: Bool, downloadedImage: UIImage, senderImage: String) {
        self.init(
            mediaURL: mediaURL,
            userName: userName,
            timeText: time,
            mediaType: mediaType,
            placeholder: Image(systemName: "photo"),
            errorView: Image(systemName: "exclamationmark.triangle"),
            isSender: isSender,
            downloadedImage: downloadedImage, senderImage: senderImage
        )
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

    func play() {
        guard let p = player else { return }
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
