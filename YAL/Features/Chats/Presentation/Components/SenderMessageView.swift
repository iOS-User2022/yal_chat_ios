//
//  SenderMessageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import SDWebImageSwiftUI

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
    var onURLTapped: ((String) -> Void)? = nil

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
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        // Show text only if message doesn't contain URL, or if there's text beyond the URL
                        if !message.containsURL || !message.contentWithoutURLs.isEmpty {
                            textSection
                        }
                        
                        // URL Preview for sent messages (WhatsApp style - shows preview only)
                        if message.containsURL, let urlString = message.firstURL {
                            URLPreviewForMessage(
                                urlString: urlString,
                                message: message,
                                onURLTapped: onURLTapped
                            )
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 8)
                            .padding(.top, message.containsURL && !message.contentWithoutURLs.isEmpty ? 0 : 8)
                        }
                    }
                    
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
        let localOverride: URL? = {
            message.mediaInfo?.localURL.flatMap { URL(string: $0.absoluteString) }
        }()
        
        MediaView(
            mediaURL: message.mediaUrl ?? "",
            userName: "You",
            timeText: formattedTime(message.timestamp),
            mediaType: mediaType,
            placeholder: placeholderWithProgress,
            errorView: errorView,
            isSender: true,
            downloadedImage: UIImage(),
            senderImage: senderImage,
            localURLOverride: localOverride,
            externalProgress: message.downloadProgress,
            isUploading: (message.messageStatus == .sending) || (message.downloadState == .downloading)
        )
        .frame(width: mediaType == .audio ? 260 : nil)
        .fixedSize(horizontal: mediaType != .audio, vertical: false)
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

    // MARK: - Placeholder View
    private var placeholderWithProgress: some View {
        ZStack(alignment: .bottom) {
            
            let mediaType = MediaType(rawValue: message.msgType) ?? .image
            
            if mediaType == .image {
                if let preview = message.localPreviewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(preview.size.width / preview.size.height, contentMode: .fit)
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                } else {
                    Image("image-placeholder")
                        .resizable()
                        .scaledToFit()
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
                        .aspectRatio(preview.size.width / preview.size.height, contentMode: .fit)
                        .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                } else {
                    Image("image-placeholder")
                        .resizable()
                        .scaledToFit()
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
        // Show content without URLs if URL exists, otherwise show full content
        let displayText = message.containsURL ? message.contentWithoutURLs : message.content
        return HighlightedText(text: displayText, searchText: searchText)
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
// MARK: - URL Preview Component for Messages
struct URLPreviewForMessage: View {
    let urlString: String
    let message: ChatMessageModel
    var onURLTapped: ((String) -> Void)? = nil
    
    @StateObject private var previewFetcher = URLPreviewFetcher()
    @State private var hasAttemptedFetch = false
    
    var body: some View {
        Group {
            if let cachedPreview = URLPreviewCache.shared.getPreview(for: urlString) {
                URLPreviewCard(previewData: cachedPreview) {
                    openURL(urlString)
                }
            } else if previewFetcher.isLoading {
                LoadingPreviewView()
            } else if let preview = previewFetcher.previewData {
                URLPreviewCard(previewData: preview) {
                    openURL(urlString)
                }
                .onAppear {
                    URLPreviewCache.shared.setPreview(preview, for: urlString)
                }
            } else {
                // Show fallback preview even if fetch failed or hasn't completed
                fallbackPreview
            }
        }
        .onAppear {
            fetchPreviewIfNeeded()
        }
    }
    
    private var fallbackPreview: some View {
        // Create a minimal preview with domain and favicon
        let domain = URL(string: urlString)?.host ?? urlString
        let faviconURL = "https://\(domain)/favicon.ico"
        
        return Button(action: {
            openURL(urlString)
        }) {
            HStack(spacing: 12) {
                // Favicon or globe icon
                AsyncImage(url: URL(string: faviconURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "globe")
                        .foregroundColor(.gray)
                }
                .frame(width: 24, height: 24)
                .cornerRadius(4)
                
                // Domain and URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(domain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(urlString)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fetchPreviewIfNeeded() {
        guard !hasAttemptedFetch else { return }
        
        // Check cache first
        if URLPreviewCache.shared.getPreview(for: urlString) != nil {
            return
        }
        
        // Fetch from network
        hasAttemptedFetch = true
        Task {
            await previewFetcher.fetchPreview(for: urlString)
        }
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
}
// MARK: - Loading Preview View
struct LoadingPreviewView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Loading preview...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
