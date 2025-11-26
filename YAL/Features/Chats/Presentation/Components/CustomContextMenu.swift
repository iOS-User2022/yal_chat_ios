//
//  CustomContextMenu.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/06/25.
//


import SwiftUI

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
    let gapBetween: CGFloat = 12
    
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
        ZStack {
            // Emoji Bar - above bubble
            emojiBar
                .frame(width: emojiBarWidth, height: emojiBarHeight)
                .position(
                    x: emojiBarX,
                    y: message.isTextMessage ? max(bubbleFrame.minY - gapBetween - emojiBarHeight - bubbleFrame.height, emojiBarHeight/2) : max(bubbleFrame.minY - gapBetween - emojiBarHeight - emojiBarHeight, emojiBarHeight/2)
                )

            // Bubble Preview (for highlight effect)
            bubblePreview

            // Menu - below bubble
            menuView(actions: actions)
                .frame(width: menuWidth) // Removed fixed height
                .position(
                    x: bubbleX-30,
                    y: menuYposition// Uses dynamic height
                )
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
        .padding(.horizontal,30)
    }
    
    private var emojiBarX: CGFloat {
        if isSender {
            // Align trailing side, but don’t go outside screen
            if message.isTextMessage {
                return min(bubbleFrame.maxX  - emojiBarWidth/2 - 16,
                           screenSize.width - emojiBarWidth/2 - 16)
            } else {
                return min(bubbleFrame.maxX  - emojiBarWidth/2 - 16, screenSize.width - emojiBarWidth/2 - 16)
            }
        } else {
            // Align leading edge of emoji bar with bubble leading edge
            return bubbleX
        }
    }
    
    private var menuYposition: CGFloat {
        
        if isSender {
            // Align trailing side, but don’t go outside screen
            if message.isTextMessage {
                return min(bubbleFrame.maxY + gapBetween + bubbleFrame.height + 32, screenSize.height - dynamicMenuHeight/2 - 16 )
            } else {
                return min(bubbleFrame.maxY + gapBetween + gapBetween + 64, screenSize.height - dynamicMenuHeight/2 - 16 )
            }
        } else {
            if message.isTextMessage {
                return min(bubbleFrame.maxY + gapBetween + bubbleFrame.height + 32 , screenSize.height - dynamicMenuHeight/2 - 16 )
                
            } else {
                return min(bubbleFrame.maxY + gapBetween + 64, screenSize.height - dynamicMenuHeight/2 - 16 )

            }
            // Align leading edge of emoji bar with bubble leading edge
        }
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

    private var bubblePreview: some View {
        Group {
            if isSender {
                let senderModel = members.first { $0.userId == message.sender }
                let senderName = senderModel?.fullName ?? senderModel?.phoneNumber
                SenderMessageView(message: message, senderName: senderName, selectedEventId: nil, searchText: "")
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
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(.leading, 32)
                    .padding(.vertical, 12)
                Spacer().frame(width: 12)
                Text(label)
                    .font(Design.Font.regular(14))
                    .padding(.trailing, 32)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            .foregroundColor(Design.Color.primaryText.opacity(0.6))
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
