//
//  ReceiverMessageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import SDWebImageSwiftUI
import AVKit

struct ReceiverMessageView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @ObservedObject var message: ChatMessageModel

    @State private var downloadRequested = false
    @State private var isVideoPlayerPresented = false
    @State private var downloadedImage: UIImage?
    
    @StateObject private var previewFetcher = URLPreviewFetcher()

    var isForwarding: Bool? = false

    let isGroupChat: Bool
    let senderName: String?
    let senderAvatarURL: String?
    let showSenderInfo: Bool // Set this to `false` if previous message was from the same user
    let onAvatarTap: (() -> Void)?
    var onDownloadNeeded: ((ChatMessageModel) -> Void)?
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onMessageRead: (() -> Void)?
    var onScrollToMessage: ((String) -> Void)?
    var onEmoji: (() -> Void)?
    var onToggleChange: (() -> Void)?
    var onURLTapped: ((String) -> Void)?
    let selectedEventId: String?
    let searchText: String
    let isFromSelection: Bool

    init(
        message: ChatMessageModel,
        isVideoPlayerPresented: Bool = false,
        isGroupChat: Bool = false,
        senderName: String? = nil,
        senderAvatarURL: String? = nil,
        showSenderInfo: Bool = false,
        onAvatarTap: (() -> Void)? = nil,
        onDownloadNeeded: ((ChatMessageModel) -> Void)? = nil,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onMessageRead: (() -> Void)? = nil,
        onScrollToMessage: ((String) -> Void)? = nil,
        onURLTapped: ((String) -> Void)? = nil,
        onToggleChange: (() -> Void)? = nil,
        selectedEventId: String? = nil,
        searchText: String = "",
        isForwarding: Bool,
        isFromSelection: Bool = false
    ) {
        self.message = message
        self.isVideoPlayerPresented = isVideoPlayerPresented
        self.isGroupChat = isGroupChat
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.showSenderInfo = showSenderInfo
        self.onAvatarTap = onAvatarTap
        self.onDownloadNeeded = onDownloadNeeded
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onMessageRead = onMessageRead
        self.onScrollToMessage = onScrollToMessage
        self.selectedEventId = selectedEventId
        self.searchText = searchText
        self.isForwarding = isForwarding
        self.onToggleChange = onToggleChange
        self.isFromSelection = isFromSelection
        self.onURLTapped = onURLTapped
    }
    
    var body: some View {
        VStack() {
            if isForwarding == true {
                Toggle(isOn: $message.isSelected) {
                    messageBubble.disabled(true)
                }
                .toggleStyle(CheckboxToggleStyle())
                .onChange(of: message.isSelected) { newValue in
                    onToggleChange?()
                }
                
            } else {
                if isGroupChat {
                    if let mediaType = MediaType(rawValue: message.msgType), mediaType  == .audio, isFromSelection == false {
                        Spacer(minLength: 35.0)
                    }
                    avatarView
                        .opacity(showSenderInfo ? 1.0 : 0.0)
                        .onTapGesture { onAvatarTap?() }
                    messageBubble
                } else {
                    messageBubble
                }
            }
            
            // Add URL Preview
                     if message.containsURL, let urlString = message.firstURL {
                         if let cachedPreview = URLPreviewCache.shared.getPreview(for: urlString) {
                             URLPreviewCard(previewData: cachedPreview) {
                                 openURL(urlString)
                             }
                             .padding(.top, 4)
                         } else if previewFetcher.isLoading {
                             HStack {
                                 ProgressView()
                                 Text("Loading preview...")
                                     .font(.caption)
                                     .foregroundColor(.gray)
                             }
                             .frame(maxWidth: .infinity)
                             .frame(height: 60)
                             .background(Color(.systemGray6))
                             .cornerRadius(8)
                         } else if let preview = previewFetcher.previewData {
                             URLPreviewCard(previewData: preview) {
                                 openURL(urlString)
                             }
                             .padding(.top, 4)
                             .onAppear {
                                 URLPreviewCache.shared.setPreview(preview, for: urlString)
                             }
                         }
                     }
            Spacer()
        }
        .padding(.leading, 20)
        .onAppear {
            triggerDownloadIfNeeded()
            if message.messageStatus != .read {
                message.messageStatus = .read
                onMessageRead?()
            }
            downLoadAvatarIfNeeded()
            
            // Fetch preview when message appears
                       if message.containsURL,
                          let urlString = message.firstURL,
                          URLPreviewCache.shared.getPreview(for: urlString) == nil,
                          previewFetcher.previewData == nil {
                           Task {
                               await previewFetcher.fetchPreview(for: urlString)
                           }
                       }
                   
        }
        .onChange(of: message.mediaUrl) { _ in triggerDownloadIfNeeded() }
    }

    // MARK: - Media Section
    private var hasMedia: Bool {
        if let type = MessageType(rawValue: message.msgType) {
            return type != .text
        }
        return false
    }
    private func openURL(_ urlString: String) {
        if let onURLTapped = onURLTapped {
            // Let the parent (ChatView) handle presenting WebViewScreen
            onURLTapped(urlString)
        } else if let url = URL(string: urlString) {
            // Fallback to opening in the system browser if no handler is provided
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        let mediaType = MediaType(rawValue: message.msgType) ?? .image
        MediaView(
            mediaURL: message.mediaUrl ?? "",
            userName: senderName,
            timeText: formattedTime(message.timestamp),
            mediaType: mediaType,
            placeholder: placeholderWithProgress,
            errorView: errorView,
            isSender: false,
            downloadedImage: downloadedImage, senderImage: ""
        )
        .id(message.mediaUrl ?? UUID().uuidString)
        .frame(width: mediaType == .audio ? 260 : 220,
               height: (mediaType == .image || mediaType == .video || mediaType == .gif) ? 215: 56)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topRight, .bottomLeft, .bottomRight]))
    }
    
    var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Failed to load")
                .font(.caption2)
                .foregroundColor(.red)
        }
        .frame(width: 220, height: 215)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Media Content
    @ViewBuilder
    private func mediaContent(from url: URL) -> some View {
        let cornerShape = CustomRoundedCornersShape(radius: 8, roundedCorners: [.topRight, .bottomLeft, .bottomRight])
        
        if message.isImageMessage {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 220, height: 215)
                    .clipShape(cornerShape)
            } else {
                Text("Image failed to load")
                    .foregroundColor(.red)
                    .frame(width: 220, height: 215)
                    .clipShape(cornerShape)
            }
        } else if message.isVideoMessage {
            ZStack {
                Rectangle().fill(Color.black.opacity(0.1))
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            }
            .frame(width: 220, height: 215)
            .clipShape(cornerShape)
            .onTapGesture { isVideoPlayerPresented = true }
            .sheet(isPresented: $isVideoPlayerPresented) {
                AVPlayerView(player: AVPlayer(url: url))
            }
        } else if message.isFileMessage {
            HStack {
                Image(systemName: "doc.fill").foregroundColor(.gray)
                Button("Open File") {
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var placeholderWithProgress: some View {
        ZStack(alignment: .bottom) {
            let mediaType = MediaType(rawValue: message.msgType) ?? .image

            if mediaType == .image || mediaType == .gif {
                Image(message.isImageMessage ? "image-placeholder" : "image-placeholder")
                    .resizable()
                    .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topRight, .bottomLeft, .bottomRight]))
               
            } else if mediaType == .video {
                ZStack {
                    Image("image-placeholder")
                        .resizable()
                        .scaledToFill()
                        .clipShape(
                            CustomRoundedCornersShape(
                                radius: 8,
                                roundedCorners: [.topRight, .bottomLeft, .bottomRight]
                            )
                        )
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
            } else if mediaType == .audio {
                VoiceMessageBubble(receiverAvatar: Image(uiImage: UIImage()), isSender: false)
            } else {
                DocumentMessageBubble(
                    thumbnail: nil,
                    fileName: "loading...",
                    metaTop: "",
                    metaMid: "0",
                    metaBot: "0",
                    time: "00:00"
                )
                .contentShape(Rectangle())
            }

            ProgressView(value: message.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 4)
                .frame(maxWidth: .infinity)
                .background(Design.Color.appGradient)
                .zIndex(1)
        }
    }

    // MARK: - Text Section
    private var textSection: some View {
        HighlightedText(text: message.content, searchText: searchText)
            .font(Design.Font.regular(14))
            .foregroundColor(Design.Color.primaryText)
            .padding(.leading, 8)
            .padding(.trailing, 8)
    }
    
    private var redactedPlaceholder: some View {
        // Deleted placeholder
        HighlightedText(text: thisMessageWasDeleted, searchText: searchText)
            .font(Design.Font.italic(14))
            .foregroundColor(Design.Color.primaryText)
            .padding(.leading, 8)
            .padding(.trailing, 8)
    }

    // MARK: - Timestamp Section
    private var timestampSection: some View {
        HStack(spacing: 4) {
            Text(formattedTime(message.timestamp))
                .font(Design.Font.regular(8))
                .foregroundColor(Design.Color.receiverTime)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Background
    private var bubbleBackground: some View {
        CustomRoundedCornersShape(
            radius: 8,
            roundedCorners: [.topRight, .bottomLeft, .bottomRight]
        )
        .fill(Design.Color.white)
    }
    
    // MARK: - Helpers
    private func triggerDownloadIfNeeded() {
        if message.mediaInfo?.localURL == nil,
           message.downloadState != .downloaded,
           message.mediaUrl != nil,
           !downloadRequested {
            downloadRequested = true
            //onDownloadNeeded?(message)
        }
    }

    private func formattedTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let image = downloadedImage {
            Image(uiImage: image)
                .resizable()
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Design.Color.white, lineWidth: 1)
                )
        } else {
            placeholderInitialsView
        }
    }

    private var placeholderInitialsView: some View {
        return Text(getInitials(from: senderName ?? "Unknown"))
            .font(Design.Font.bold(8))
            .frame(width: 20, height: 20)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryText.opacity(0.7))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Design.Color.white, lineWidth: 1)
            )
    }
    
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Spacer().frame(height: 2)
                if isGroupChat && showSenderInfo {
                    Text(senderName ?? "Unknown")
//                        .font(.caption)
                        .font(Design.Font.regular(8))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                    
                }
                
                if message.isRedacted || message.content == thisMessageWasDeleted {
                    redactedPlaceholder
                    timestampSection

                } else {
                    if hasMedia { mediaSection }
                    
                    if let replied = message.inReplyTo {
                        let senderId = replied.sender
                        let senderModel = ContactManager.shared.contact(for: senderId)
                        let senderName = senderModel?.fullName ?? senderModel?.phoneNumber ?? "Unknown"
                        let currentUserId = replied.currentUserId
                        ReplyPreviewView(
                            message: replied,
                            senderName: senderId == currentUserId ? "You" : senderName,
                            onTapReplyMessage: {
                                onScrollToMessage?(replied.eventId)
                            }
                        )
                    }
                    
                    textSection
                    timestampSection
                }
                
            }
            .background(
                ZStack {
                    bubbleBackground
                    if selectedEventId == message.eventId {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: MessageBubbleAnchorKey.self,
                                value: geo.frame(in: .global)
                            )
                        }
                        .allowsHitTesting(false)
                    }
                }
            )
            .onTapGesture { onTap?() }
            .onLongPressGesture { onLongPress?() }
            
            if !message.reactions.isEmpty {
                reactionsBar
                    .background(Design.Color.lighterGrayBackground)
                    .cornerRadius(20)
                    .padding(.top, -2) // slightly overlaps the bubble
                    .padding(.bottom, 8) // space below bar to next message
            }
        }
    }
    
    private var reactionsBar: some View {
        // If you want to group and dedupe emojis:
        let grouped = Dictionary(grouping: message.reactions, by: { $0.key })
        let sortedKeys = grouped.keys.sorted(by: <)
        // If you want counts, build a string:
        let emojiString = sortedKeys.joined(separator: " ")
        let totalReactions = message.reactions.count
        // If you want only one per user, or only unique emojis, just use Set, etc.

        return Group {
            if !emojiString.isEmpty {
                HStack(alignment: .top, spacing: 2) {
                    Text(emojiString)
                        .font(Design.Font.regular(12))
                        .lineSpacing(2)
                        .padding(.vertical, 3)
                        .fixedSize(horizontal: false, vertical: true) // <-- this lets it wrap
                    
                    Text("\(totalReactions)")
                        .font(Design.Font.regular(10))
                        .foregroundColor(Design.Color.tertiaryText)
                        .padding(.top, 3)
                        .padding(.trailing, 3)
                }
                .padding(.horizontal, 3)
            }
        }
    }
    
    private func downLoadAvatarIfNeeded() {
        if let urlString = senderAvatarURL, !urlString.isEmpty {
            MediaCacheManager.shared.getMedia(
                url: urlString,
                type: .image,
                progressHandler: { _ in }
            ) { result in
                switch result {
                case .success(let imagePath):
                    var fileURL: URL
                    
                    if imagePath.hasPrefix("file://") {
                        if let url = URL(string: imagePath) {
                            fileURL = url
                        } else {
                            print("Invalid URL path: \(imagePath)")
                            return
                        }
                    } else {
                        fileURL = URL(fileURLWithPath: imagePath)
                    }
                    // More efficient than loading Data first
                    if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                        // fallback if the path form fails for some reason
                        guard let data = try? Data(contentsOf: fileURL) else { return nil }
                        return UIImage(data: data)
                    }() {
                        // Optional: pre-decompress for smoother UI on iOS 15+
                        let finalImage = uiImage.preparingForDisplay() ?? uiImage
                        DispatchQueue.main.async {
                            downloadedImage = finalImage
                        }
                    }
                case .failure(let error):
                    print("ChatHeaderView: failed to load image \(error)")
                }
            }
        }
    }
    @ViewBuilder
       func messageContentWithPreview() -> some View {
           VStack(alignment: .leading, spacing: 8) {
               // Original message content
               Text(message.content)
                   .font(.system(size: 15))
                   .foregroundColor(.primary)
               
               // URL Preview
               if message.containsURL, let urlString = message.firstURL {
                   URLPreviewForMessage(
                       urlString: urlString,
                       message: message,
                       onURLTapped: onURLTapped
                   )
               }
           }
       }
}

// MARK: - Reply Preview View
private struct ReplyPreviewView: View {
    let message: ChatMessageModel
    let senderName: String?
    let onTapReplyMessage: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Spacer().frame(height: 8)
                if let senderName = senderName {
                    Text(senderName)
                        .font(Design.Font.medium(12))
                        .foregroundColor(Design.Color.navy)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                }
                if message.isRedacted || message.content == thisMessageWasDeleted{
                    // Deleted placeholder
                    Text(thisMessageWasDeleted)
                        .font(Design.Font.italic(12))
                        .foregroundColor(Design.Color.primaryText)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                } else {
                    if message.isImageMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("Photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text(message.content)
                            .font(Design.Font.regular(12))
                            .foregroundColor(Design.Color.primaryText)
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                    }
                    Spacer().frame(height: 8)
                }
            }
            .background(Design.Color.lightWhiteBackground)
            .cornerRadius(8)
            .padding(.leading, 2)
            .padding(.trailing, 0)
        }
        .background(Design.Color.black)
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .onTapGesture {
            onTapReplyMessage?()
        }
    }
}


import SwiftUI

struct HighlightedText: View {
    let text: String
    let searchText: String
    let highlightColor: UIColor = .systemGray4

    private var highlightedAttributedString: AttributedString {
        guard !searchText.isEmpty else { return AttributedString(text) }

        let nsText = text as NSString
        let mutable = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: nsText.length)
        let pattern = NSRegularExpression.escapedPattern(for: searchText)

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            for match in regex.matches(in: text, options: [], range: fullRange) {
                mutable.addAttribute(.backgroundColor,
                                     value: highlightColor,
                                     range: match.range)
            }
        }

        return AttributedString(mutable)
    }

    var body: some View {
        Text(highlightedAttributedString)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}
