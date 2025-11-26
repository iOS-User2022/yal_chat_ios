//
//  SenderMessageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import SDWebImageSwiftUI
import AVKit

struct SenderMessageView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @ObservedObject var message: ChatMessageModel
    let senderName: String?
    @State private var downloadRequested = false
    @State private var isVideoPlayerPresented = false

    var onDownloadNeeded: ((ChatMessageModel) -> Void)?
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onEmoji: (() -> Void)?
    var onScrollToMessage: ((String) -> Void)?
    let selectedEventId: String?
    let searchText: String
    var isForwarding: Bool? = false
    var onToggleChange: (() -> Void)?
    var senderImage: String = ""

    var body: some View {
        HStack(alignment: .top) {
            if isForwarding == true {
                Toggle(isOn: $message.isSelected) {
                    messgeBubble.disabled(true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onChange(of: message.isSelected) { newValue in
                    onToggleChange?()
                }
                .toggleStyle(CheckboxToggleStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                messgeBubble
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.trailing, 20)
    }
    
    @ViewBuilder
    private var messgeBubble: some View {
        VStack(alignment: .trailing, spacing: 0)  {
            VStack(alignment: .trailing, spacing: 0) {
                
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
                    // GeometryReader ONLY if this bubble is selected
                    if selectedEventId == message.eventId {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: MessageBubbleAnchorKey.self,
                                value: geo.frame(in: .global)
                            )
                        }
                    }
                }
            )
            .onTapGesture { onTap?() }
            .onLongPressGesture {
                onLongPress?()
            }
            .onAppear { triggerDownloadIfNeeded() }
            .onChange(of: message.mediaUrl) { _ in triggerDownloadIfNeeded() }
            
            if !message.reactions.isEmpty {
                reactionsBar
                    .background(Design.Color.lighterGrayBackground)
                    .cornerRadius(20)
                    .padding(.top, -2) // slightly overlap bubble
                    .padding(.bottom, 8) // space below bar
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
                        .padding(.horizontal, 3)
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

    // MARK: - Media Check
    private var hasMedia: Bool {
        MessageType(rawValue: message.msgType) != .text
    }

    // MARK: - Media Section
    @ViewBuilder
    private var mediaSection: some View {
        let mediaType = MediaType(rawValue: message.msgType) ?? .image
        MediaView(
            mediaURL: message.mediaUrl ?? "",
            userName: "You",
            timeText: formattedTime(message.timestamp),
            mediaType: MediaType(rawValue: message.msgType) ?? .image,
            placeholder: placeholderWithProgress,
            errorView: errorView,
            isSender: true, downloadedImage: UIImage(), senderImage: senderImage
        )
        .frame(width: mediaType == .audio ? 260 : 220,
               height: (mediaType == .image || mediaType == .video || mediaType == .gif) ? 215: 56)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topRight, .topLeft]))
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
        let cornerShape = CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight])
        
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

    // MARK: - Placeholder View
    private var placeholderWithProgress: some View {
        ZStack(alignment: .bottom) {
            
            let mediaType = MediaType(rawValue: message.msgType) ?? .image
            
            if mediaType == .image {
                if let preview = message.localPreviewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                } else {
                    Image("image-placeholder")
                        .resizable()
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                }
                
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
                VoiceMessageBubble(receiverAvatar: Image(uiImage: UIImage()), isSender: true)
            } else if mediaType == .gif {
                if let preview = message.localPreviewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                } else {
                    Image("image-placeholder")
                        .resizable()
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                }
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
                .background(Design.Color.white)
                .zIndex(1)
        }
    }

    // MARK: - Text Section
    private var textSection: some View {
        HighlightedText(text: message.content, searchText: searchText)
            .font(Design.Font.regular(14))
            .foregroundColor(Design.Color.white)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    private var redactedPlaceholder: some View {
        // Deleted placeholder
        HighlightedText(text: thisMessageWasDeleted, searchText: searchText)
            .font(Design.Font.italic(14))
            .foregroundColor(Design.Color.white)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }

    // MARK: - Timestamp Section
    private var timestampSection: some View {
        HStack(spacing: 4) {
            Text(formattedTime(message.timestamp))
                .font(Design.Font.regular(8))
                .foregroundColor(Design.Color.senderTime)
            Image(message.messageStatus.imageName)
                .resizable()
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Bubble Background
    private var bubbleBackground: some View {
        CustomRoundedCornersShape(
            radius: 8,
            roundedCorners: [.topRight, .topLeft, .bottomLeft]
        )
        .fill(Design.Color.appGradient)
    }
    
    // MARK: - Helpers
    private func triggerDownloadIfNeeded() {
        if message.mediaInfo?.localURL == nil,
           message.mediaUrl != nil,
           !downloadRequested {
            downloadRequested = true
            onDownloadNeeded?(message)
        }
    }

    private func formattedTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
                if message.isRedacted  || message.content == thisMessageWasDeleted{
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
