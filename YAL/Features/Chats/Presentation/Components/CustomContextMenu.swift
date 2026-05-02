//
//  CustomContextMenu.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/06/25.
//


import SwiftUI
import SDWebImageSwiftUI
import AVFoundation

enum ContextMenuAction: String, CaseIterable, Identifiable {
    case reply
    case copy
    case forward
    case delete
    case info

    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .reply: "Reply"
        case .copy: "Copy"
        case .forward: "Forward"
        case .delete: "Delete"
        case .info: "Info"
        }
    }
    var icon: String {
        switch self {
        case .reply: "undo"
        case .copy: "copy"
        case .forward: "forward"
        case .delete: "delete"
        case .info: "info"
        }
    }
}

struct CustomContextMenu: View {
    let message: ChatMessageModel
    let previousMessage: ChatMessageModel?
    let isSender: Bool
    let members: [ContactModel]
    let isGroupChat: Bool
    let nsPopover: Namespace.ID
    let bubbleFrame: CGRect
    let screenSize: CGSize
    let onReply: (ChatMessageModel) -> Void
    let onCopy: (ChatMessageModel) -> Void
    let onForward: (ChatMessageModel) -> Void
    let onDelete: (ChatMessageModel) -> Void
    let onEmojiSelect: (Emoji) -> Void
    let onDismiss: () -> Void
    let onInfo: (ChatMessageModel) -> Void

    let menuWidth: CGFloat = 166
    let emojiBarWidth: CGFloat = (24 * 7) + (8 * 8)
    let cornerRadius: CGFloat = 20
    let emojiBarHeight: CGFloat = 44
    let gapBetween: CGFloat = 2
    let messagePreviewHeight: CGFloat = 60
    let messagePreviewMaxWidth: CGFloat = 250 // Max width like actual chat bubbles
    
    @State private var showEmojiPicker = false
    
    var actions: [ContextMenuAction] {
        isSender ? [.reply, .copy, .forward, .delete, .info] : [.reply, .copy, .forward, .delete]
    }

    // NEW: Calculate menuHeight dynamically based on number of actions
    private var dynamicMenuHeight: CGFloat {
        let rowHeight: CGFloat = 44
        let topBottomPadding: CGFloat = 32 // 16 top + 16 bottom
        return CGFloat(actions.count) * rowHeight + topBottomPadding
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                menuView(actions: actions)
                          .frame(width: menuWidth, height: dynamicMenuHeight)
                          .position(
                              x: menuAndPreviewX,
                              y: menuYposition
                          )
                          .zIndex(28)
                      
                      // LAYER 2 (Middle): Message Preview - in the middle
                      messagePreviewView
                          .frame(maxWidth: messagePreviewMaxWidth, alignment: isSender ? .trailing : .leading)
                          .fixedSize(horizontal: false, vertical: true)
                          .position(
                              x: messagePreviewX,
                              y: messagePreviewY
                          )
                          .zIndex(29)
                          .allowsHitTesting(false)
                      
                      // LAYER 3 (Top): Emoji Bar - at the very top
                      emojiBar
                          .frame(width: emojiBarWidth, height: emojiBarHeight)
                          .position(
                              x: emojiBarX,
                              y: emojiBarY
                          )
                          .zIndex(30)
                  }
                  .sheet(isPresented: $showEmojiPicker) {
                      EmojiPickerSheet(
                          onSelect: { emoji in
                              onEmojiSelect(emoji)
                              showEmojiPicker = false
                              onDismiss()
                          }
                      )
                      .presentationDetents([.medium, .large])
                  }
                  .edgesIgnoringSafeArea(.all)
                  .padding(.horizontal, 30)
                  }
    }

    // Calculate trailing edge X position (right edge for sender)
    private var trailingEdgeX: CGFloat {
        if isSender {
            let desiredRightEdge = min(bubbleFrame.maxX - 30, screenSize.width - 16)
            return desiredRightEdge
        } else {
            return 0
        }
    }
    
    // Calculate leading edge X position (left edge for receiver)
    private var leadingEdgeX: CGFloat {
        if isSender {
            return 0
        } else {
            return message.isAudioMessage && isGroupChat ?
                max(bubbleFrame.minX + 35 - 30, 16) :
                max(bubbleFrame.minX - 30, 16)
        }
    }
    private var menuAndPreviewX: CGFloat {
        if isSender {
            return trailingEdgeX - menuWidth/2
        } else {
            return leadingEdgeX + menuWidth/2
        }
    }
    private var emojiBarX: CGFloat {
        if isSender {
            let menuRightEdge = trailingEdgeX
            return menuRightEdge - emojiBarWidth/2
        } else {
            let menuLeftEdge = leadingEdgeX
            return menuLeftEdge + emojiBarWidth/2
        }
    }
    
    private var messagePreviewTrailingX: CGFloat {
        return trailingEdgeX
    }
    
    private var emojiBarY: CGFloat {
        let spacing: CGFloat = 20
           let estimatedPreviewHeight = calculatePreviewHeight()
           let previewTopEdge = messagePreviewY - (estimatedPreviewHeight / 2)
           let emojiBarCenter = previewTopEdge - spacing - (emojiBarHeight / 2)
           let minY = emojiBarHeight / 2 + 60
           return max(emojiBarCenter, minY)
    }
   
    private var messagePreviewX: CGFloat {
        if isSender {
            return trailingEdgeX - messagePreviewMaxWidth/2
        } else {
            return leadingEdgeX + messagePreviewMaxWidth/2
        }
    }
    
    private var messagePreviewY: CGFloat {
        let spacing: CGFloat = 12
          let estimatedPreviewHeight = calculatePreviewHeight()
          let menuTopEdge = menuYposition - (dynamicMenuHeight / 2)
          let previewCenter = menuTopEdge - spacing - (estimatedPreviewHeight / 2)
          let minY = estimatedPreviewHeight / 2 + 100
          return max(previewCenter, minY)
    }

    private func calculatePreviewHeight() -> CGFloat {
        var height: CGFloat = 0
        height += 8
        if isGroupChat && !isSender {
        height += 18 // Name text + spacing
        }
            if message.inReplyTo != nil {
            height += 80 // Reply container with padding
        }
        
        // Main content height calculation
        if message.isRedacted || message.content == thisMessageWasDeleted {
            height += 40 // Deleted message text + padding
        } else if message.isTextMessage {
            let contentToShow = message.containsURL ? message.contentWithoutURLs : message.content
            let estimatedLines = min(3, max(1, contentToShow.count / 30)) // More conservative line estimation
            height += CGFloat(estimatedLines * 20) + 16
            
            // Add URL preview height if present
            if message.containsURL {
                height += 100 // URL preview card height
            }
        } else if message.isAudioMessage {
            height += 70 // Audio waveform preview height
        } else if message.isImageMessage || message.isVideoMessage || message.msgType == MediaType.gif.rawValue {
            // Calculate image height based on aspect ratio
            if let preview = message.localPreviewImage {
                let aspectRatio = preview.size.width / preview.size.height
                let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio, maxWidth: messagePreviewMaxWidth - 16)
                let imageHeight = displayWidth / aspectRatio
                height += min(imageHeight, 180) // Cap image preview height
            } else {
                height += 150 // Default media height
            }
        } else if message.isFileMessage {
            height += 50 // File/document preview height
        } else {
            height += 50 // Default fallback content height
        }
        
        // Timestamp row
        height += 28 // Timestamp + padding
        height += 8
        
        // Cap at maximum height (35% of screen to ensure it fits)
        let maxHeight = screenSize.height * 0.35
        return min(height, maxHeight)
    }

    
    private func calculateDisplayWidth(aspectRatio: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let targetHeight: CGFloat = 150
        let minWidth: CGFloat = 100
        let maxWidthConstraint: CGFloat = maxWidth
        
        let calculatedWidth = targetHeight * aspectRatio
        
        if aspectRatio > 1.5 {
            return min(calculatedWidth, maxWidthConstraint)
        } else if aspectRatio > 1.0 {
            return min(calculatedWidth, maxWidthConstraint)
        } else {
            return min(maxWidthConstraint, max(minWidth, calculatedWidth))
        }
    }
   

    private var menuYposition: CGFloat {
        // Position menu based on where the user long-pressed the message
        let safeAreaBottom: CGFloat = 34
          let screenBottom = screenSize.height - safeAreaBottom - 17
          
          // Position menu near bottom with some padding
          let menuBottomPadding: CGFloat = 40
          let menuY = screenBottom - menuBottomPadding - (dynamicMenuHeight / 2)
          
          // Ensure menu doesn't go off screen
          return max(menuY, dynamicMenuHeight / 2 + 60)
    }

    // Horizontal anchor: center of bubble, or right/left edge (based on alignment)
    private var bubbleX: CGFloat {
        if isSender {
            if message.isTextMessage {
                return min(bubbleFrame.maxX - menuWidth/2, screenSize.width - menuWidth/2 - 16)
                
            }  else {
                return min(bubbleFrame.maxX - menuWidth/2, screenSize.width - menuWidth/2 - 16)
            }
        } else {
            if message.isAudioMessage && isGroupChat {
                return max(bubbleFrame.minX + 35 , menuWidth/2)
            }
            else {
                return max(bubbleFrame.minX + menuWidth/2, menuWidth/2)
            }
           
        }
    }
    

    private var emojiBar: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EmojiStore.shared.recents.prefix(12), id: \.id) { emoji in
                        Text(emoji.symbol)
                            .frame(width: 24, height: 24)
                            .onTapGesture {
                                onEmojiSelect(emoji)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDismiss()
                            }
                    }
                }
                .padding(.horizontal, 12)
            }
            Button(action: {
                // Show full emoji tray
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showEmojiPicker = true
            }) {
                Image("add")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .padding(4)
                    .background(Design.Color.blueGradient)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: emojiBarWidth, height: emojiBarHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
    }
    
    private var messagePreviewView: some View {
        HStack {
                if isSender {
                    Spacer(minLength: 0)
                }
                VStack(alignment: isSender ? .trailing : .leading, spacing: 0) {
                    // Show sender name in group chats (only for receiver messages)
                    if isGroupChat && !isSender {
                        let senderModel = members.first { $0.userId == message.sender }
                        let senderName = senderModel?.fullName ?? senderModel?.phoneNumber ?? ""
                        if !senderName.isEmpty {
                            Text(senderName)
                                .font(Design.Font.regular(8))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                        }
                    }
                    
                    // Show reply preview if this message is a reply
                    if let repliedMessage = message.inReplyTo {
                        compactReplyPreview(for: repliedMessage)
                    }
                    
                    // Main message content
                    let textColor = isSender ? Design.Color.white : Design.Color.primaryText
                    let iconColor = isSender ? Design.Color.white.opacity(0.9) : Design.Color.primaryText.opacity(0.7)
                    
                    if message.isRedacted || message.content == thisMessageWasDeleted {
                        Text(thisMessageWasDeleted)
                            .font(Design.Font.italic(14))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    } else if message.isTextMessage {
                        Text(message.content)
                            .font(Design.Font.regular(14))
                            .foregroundColor(textColor)
                            .lineLimit(3)
                            .multilineTextAlignment(isSender ? .trailing : .leading)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                    } else if message.isAudioMessage {
                        CompactAudioPreview(
                            mediaURL: message.mediaUrl ?? "",
                            localURL: message.mediaInfo?.localURL.flatMap { URL(string: $0.absoluteString) },
                            content: message.content,
                            textColor: textColor,
                            iconColor: iconColor
                               
                        )
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    } else if message.isImageMessage {
                        CompactMediaPreview(
                            mediaURL: message.mediaUrl ?? "",
                            mediaType: .image,
                            localURL: message.mediaInfo?.localURL.flatMap { URL(string: $0.absoluteString) },
                            previewImage: message.localPreviewImage,
                            iconColor: iconColor,
                            textColor: textColor
                        )
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    } else if message.isVideoMessage {
                        CompactMediaPreview(
                            mediaURL: message.mediaUrl ?? "",
                            mediaType: .video,
                            localURL: message.mediaInfo?.localURL.flatMap { URL(string: $0.absoluteString) },
                            previewImage: message.localPreviewImage,
                            iconColor: iconColor,
                            textColor: textColor
                        )
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    } else if message.msgType == MediaType.gif.rawValue {
                        CompactMediaPreview(
                            mediaURL: message.mediaUrl ?? "",
                            mediaType: .gif,
                            localURL: message.mediaInfo?.localURL.flatMap { URL(string: $0.absoluteString) },
                            previewImage: message.localPreviewImage,
                            iconColor: iconColor,
                            textColor: textColor
                        )
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    } else if message.isFileMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                                .font(.system(size: 11))
                                .foregroundColor(iconColor)
                            Text(message.content.isEmpty ? "Document" : message.content)
                                .font(Design.Font.regular(14))
                                .foregroundColor(textColor)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    } else {
                        Text(message.content.isEmpty ? "Message" : message.content)
                            .font(Design.Font.regular(14))
                            .foregroundColor(textColor)
                            .lineLimit(3)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                    
                    // Timestamp section
                    HStack(spacing: 4) {
                        Text(formattedTime(message.timestamp))
                            .font(Design.Font.regular(8))
                            .foregroundColor(isSender ? Design.Color.senderTime : Design.Color.primaryText.opacity(0.6))
                        if isSender {
                            Image(message.messageStatus.imageName)
                                .resizable()
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
                .background(
                    Group {
                        if isSender {
                            CustomRoundedCornersShape(
                                radius: 8,
                                roundedCorners: [.topRight, .topLeft, .bottomLeft]
                            )
                            .fill(Design.Color.appGradient)
                        } else {
                            CustomRoundedCornersShape(
                                radius: 8,
                                roundedCorners: [.topRight, .bottomLeft, .bottomRight]
                            )
                            .fill(Design.Color.lightWhiteBackground)
                        }
                    }
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .frame(maxWidth: messagePreviewMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
                
                if !isSender {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: messagePreviewMaxWidth, alignment: isSender ? .trailing : .leading)
            .fixedSize(horizontal: true, vertical: false)
    }
    
    // Helper to format timestamp
    private func formattedTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Compact Reply Preview
    @ViewBuilder
    private func compactReplyPreview(for repliedMessage: ChatMessageModel) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSender ? Design.Color.white.opacity(0.6) : Design.Color.primaryText.opacity(0.4))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Spacer().frame(height: 8)
                
                // Reply sender name
                let replySenderModel = members.first { $0.userId == repliedMessage.sender }
                let replySenderName = replySenderModel?.fullName ?? replySenderModel?.phoneNumber ?? (repliedMessage.sender == message.currentUserId ? "You" : "Unknown")
                Text(replySenderName)
                    .font(Design.Font.medium(12))
                    .foregroundColor(isSender ? Design.Color.white.opacity(0.95) : Design.Color.navy)
                    .lineLimit(1)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                
                // Reply content - Show actual content with proper truncation
                if repliedMessage.isRedacted || repliedMessage.content == thisMessageWasDeleted {
                    Text(thisMessageWasDeleted)
                        .font(Design.Font.italic(12))
                        .foregroundColor(isSender ? Design.Color.white.opacity(0.85) : Design.Color.primaryText.opacity(0.8))
                        .lineLimit(1)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                } else if repliedMessage.isImageMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 10))
                        Text("Photo")
                            .font(Design.Font.regular(12))
                    }
                    .foregroundColor(isSender ? Design.Color.white.opacity(0.9) : Design.Color.primaryText.opacity(0.7))
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                } else {
                    Text(repliedMessage.content.isEmpty ? "Message" : repliedMessage.content)
                        .font(Design.Font.regular(12))
                        .foregroundColor(isSender ? Design.Color.white.opacity(0.9) : Design.Color.primaryText.opacity(0.8))
                        .lineLimit(1)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                }
                
                Spacer().frame(height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isSender ? Design.Color.white.opacity(0.25) : Design.Color.lightWhiteBackground)
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var bubblePreview: some View {
        Group {
            if isSender {
                let senderModel = members.first { $0.userId == message.sender }
                let senderName = senderModel?.fullName ?? senderModel?.phoneNumber
                SenderMessageView(message: message, senderName: senderName, participantCount: members.count, selectedEventId: nil, searchText: "")
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 0)
            } else {
                let senderModel = members.first { $0.userId == message.sender }
                let senderName = senderModel?.fullName ?? senderModel?.phoneNumber
                let senderAvatarURL = senderModel?.avatarURL ?? senderModel?.imageURL
                let showSenderInfo = isGroupChat && (previousMessage?.sender != message.sender)
                ReceiverMessageView(
                    message: message,
                    isGroupChat: isGroupChat,
                    senderName: senderName,
                    senderAvatarURL: senderAvatarURL,
                    showSenderInfo: showSenderInfo,
                    isForwarding: false,
                    isFromSelection: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, screenSize.width * 0.30)
                .padding(.bottom, 20)
            }
        }
        .matchedGeometryEffect(
            id: message.eventId,
            in: nsPopover,
            anchor: .topLeading,
            isSource: false
        )
        .padding(.vertical, 10)
        .opacity(1)
        .blur(radius: 0)
        .overlay(
            Color.black.opacity(0.3) // Adjust opacity for darkness (0.1 to 0.5 recommended)
                .allowsHitTesting(false)
        )
    }

    private func menuView(actions: [ContextMenuAction]) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 16)
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                actionButton(label: action.label, icon: action.icon) {
                    handleAction(action)
                }
                // Avoid extra divider after last item
                if index < actions.count - 1 {
                    Divider()
                }
            }
            Spacer().frame(height: 16)
        }
        .background(.thinMaterial)
        .cornerRadius(20)
    }
    
    private func handleAction(_ action: ContextMenuAction) {
        switch action {
        case .reply: onReply(message)
        case .copy: onCopy(message)
        case .forward: onForward(message)
        case .delete: onDelete(message)
        case .info: onInfo(message)
        }
        onDismiss()
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 0) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Design.Color.primaryTextColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(.leading, 28)
                    .padding(.vertical, 12)
                Spacer().frame(width: 12)
                Text(label)
                    .font(Design.Font.regular(14))
                    .padding(.trailing, 32)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .foregroundColor(Design.Color.primaryTextColor)
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
}

struct MessageBubbleAnchorKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() { value = next }
    }
}

// MARK: - Compact Media Preview Component
struct CompactMediaPreview: View {
    let mediaURL: String
    let mediaType: MediaType
    let localURL: URL?
    let previewImage: UIImage?
    let iconColor: Color
    let textColor: Color
    
    @StateObject private var loader = MediaLoader()
    
    var body: some View {
        Group {
            // Use localURL directly if available, otherwise use loader's localURL
            let effectiveURL = localURL ?? loader.localURL
            let effectiveImage = loader.image ?? previewImage
            
            if let loadedURL = effectiveURL {
                // Show actual media preview with dynamic sizing
                if mediaType == .image {
                    if let img = effectiveImage {
                        let aspectRatio = img.size.width / img.size.height
                        let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio, maxWidth: 200)
                        
                        DownsampledLocalImage(url: loadedURL, maxPixel: 400)
                            .scaledToFit()
                            .frame(width: displayWidth, height: displayWidth / aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Fallback: use fixed size while loading
                        DownsampledLocalImage(url: loadedURL, maxPixel: 400)
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else if mediaType == .video {
                    if let thumb = effectiveImage {
                        // Use thumbnail dimensions for dynamic sizing
                        let aspectRatio = thumb.size.width / thumb.size.height
                        let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio, maxWidth: 200)
                        
                        ZStack {
                            DownsampledVideoPoster(url: loadedURL, maxPixel: 400)
                                .scaledToFit()
                                .frame(width: displayWidth, height: displayWidth / aspectRatio)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                    } else {
                        // Fallback: use fixed size while loading
                        ZStack {
                            DownsampledVideoPoster(url: loadedURL, maxPixel: 400)
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                        }
                    }
                } else if mediaType == .gif {
                    if let img = effectiveImage {
                        // Use image dimensions for dynamic sizing
                        let aspectRatio = img.size.width / img.size.height
                        let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio, maxWidth: 200)
                        
                        // Use file URL for GIF
                        let gifURL = loadedURL
                        WebImage(url: gifURL)
                            .resizable()
                            .scaledToFit()
                            .frame(width: displayWidth, height: displayWidth / aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Fallback: use fixed size while loading
                        let gifURL = loadedURL
                        WebImage(url: gifURL)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    fallbackView
                }
            } else if let preview = effectiveImage {
                // Show preview image with dynamic sizing
                let aspectRatio = preview.size.width / preview.size.height
                let displayWidth = calculateDisplayWidth(aspectRatio: aspectRatio, maxWidth: 200)
                
                if mediaType == .video {
                    ZStack {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(width: displayWidth, height: displayWidth / aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                } else {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayWidth / aspectRatio)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                // Fallback to icon + text
                fallbackView
            }
        }
        .onAppear {
            loadMediaIfNeeded()
        }
    }
    
    // Calculate display width dynamically based on aspect ratio
    private func calculateDisplayWidth(aspectRatio: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let targetHeight: CGFloat = 200
        let minWidth: CGFloat = 100
        let maxWidthConstraint: CGFloat = maxWidth
        let calculatedWidth = targetHeight * aspectRatio
        
        // Apply constraints while preserving dynamic sizing
        if aspectRatio > 1.5 {
            return min(calculatedWidth, maxWidthConstraint)
        } else if aspectRatio > 1.0 {
            return min(calculatedWidth, maxWidthConstraint)
        } else {
            return min(maxWidthConstraint, max(minWidth, calculatedWidth))
        }
    }
    
    private var fallbackView: some View {
        HStack(spacing: 6) {
            Image(systemName: mediaType == .image ? "photo" : (mediaType == .video ? "video" : "photo"))
                .font(.system(size: 11))
                .foregroundColor(iconColor)
            Text(mediaType == .image ? "Photo" : (mediaType == .video ? "Video" : "GIF"))
                .font(Design.Font.regular(14))
                .foregroundColor(textColor)
                .lineLimit(2)
        }
    }
    
    private func loadMediaIfNeeded() {
        // If we already have localURL, pass it to loader
        if let url = localURL {
            loader.load(remoteURL: mediaURL, type: mediaType, localURL: url)
            return
        }
            if previewImage != nil {
            return
        }
            guard !mediaURL.isEmpty else { return }
        
        loader.load(remoteURL: mediaURL, type: mediaType, localURL: nil)
    }
}

// MARK: - Compact Audio Preview Component
struct CompactAudioPreview: View {
    let mediaURL: String
    let localURL: URL?
    let content: String
    let textColor: Color
    let iconColor: Color
    
    @StateObject private var loader = MediaLoader()
    @State private var audioDuration: TimeInterval = 0
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                HStack(spacing: 2) {
                ForEach(0..<15, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(iconColor)
                        .frame(width: 2, height: CGFloat([8, 12, 16, 10, 14, 18, 11, 15, 9, 13, 17, 10, 14, 16, 12][index]))
                }
            }
            .frame(height: 20)
                VStack(alignment: .leading, spacing: 2) {
                if !content.isEmpty {
                    Text(content)
                        .font(Design.Font.regular(12))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }
                Text(formatDuration(audioDuration))
                    .font(Design.Font.regular(10))
                    .foregroundColor(textColor.opacity(0.7))
            }
            
            Spacer()
        }
        .onAppear {
            loadAudioIfNeeded()
        }
        .onChange(of: loader.localURL) { newURL in
            if let url = newURL {
                loadDuration(from: url)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration == 0 {
            return "0:00"
        }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadDuration(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let player = try AVAudioPlayer(data: data)
                DispatchQueue.main.async {
                    self.audioDuration = player.duration
                }
            } catch {
            }
        }
    }
    
    private func loadAudioIfNeeded() {
        if let url = localURL {
            loader.load(remoteURL: mediaURL, type: .audio, localURL: url)
            loadDuration(from: url)
        } else if !mediaURL.isEmpty {
            loader.load(remoteURL: mediaURL, type: .audio, localURL: nil)
        }
    }
}
