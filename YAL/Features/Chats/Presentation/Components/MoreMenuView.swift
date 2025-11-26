//
//  MoreMenuView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 16/09/25.
//

import SwiftUI

enum MoreMenuAction: String, CaseIterable, Identifiable {
    case markAsRead
    case markAsUnread
    case mute
    case unmute
    case addToFavorites
    case removeFromFavorites
    case block
    case unblock
    case deleteChat
    case lockChat

    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .markAsRead:
            "Mark as read"
        case .markAsUnread:
            "Mark as unread"
        case .mute:
            "Mute"
        case .unmute:
            "Unmute"
        case .addToFavorites:
            "Add to favorites"
        case .removeFromFavorites:
            "Remove from favorites"
        case .block:
            "Block"
        case .unblock:
            "Unblock"
        case .deleteChat:
            "Delete chat"
        case .lockChat:
            "Lock chat"
        }
    }
    var icon: String {
        switch self {
        case .markAsRead:
            "message"
        case .markAsUnread:
            "message-notif"
        case .mute:
            "notification-unmute"
        case .unmute:
            "notification-mute"
        case .addToFavorites:
            "favorite"
        case .removeFromFavorites:
            "un-favorite"
        case .block:
            "shield-cross"
        case .unblock:
            "shield-cross"
        case .deleteChat:
            "delete"
        case .lockChat:
            "lock"
        }
    }
}

struct MoreMenuView: View {
    var roomModel: RoomModel

    let onMarkAsRead: () -> Void
    let onMarkAsUnread: () -> Void
    let onMute: () -> Void
    let onUnmute: () -> Void
    let onAddToFavorites: () -> Void
    let onRemoveFromFavorites: () -> Void
    let onBlock: () -> Void
    let onUnblock: () -> Void
    let onDeleteChat: () -> Void
    let onLockChat: () -> Void
    let onDismiss: () -> Void

    var menuWidth: CGFloat {
        roomModel.isFavorite ? 220 : 200
    }

    let cornerRadius: CGFloat = 20
    
    var actions: [MoreMenuAction] {
        var result: [MoreMenuAction] = [
            roomModel.isRead ? .markAsUnread : .markAsRead,
            roomModel.isMuted ? .unmute : .mute,
            roomModel.isFavorite ? .removeFromFavorites : .addToFavorites,
            .deleteChat
        ]
        
        // Only show block/unblock for 1-on-1 chats (non-group)
        if !roomModel.isGroup {
            result.insert(roomModel.isBlocked ? .unblock : .block, at: result.count - 1)
        }

        var isLockedChatsEnabled: Bool = Storage.get(for: .isLockedChatsEnabled, type: .userDefaults, as: Bool.self) ?? true
        if isLockedChatsEnabled {
            if !roomModel.isLocked {
                result.append(.lockChat)
            }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room button
            roomButton(for: roomModel)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Color.white
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .frame(maxWidth: .infinity)

            // Menu actions
            VStack(spacing: 0) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    actionButton(label: action.label, icon: action.icon) {
                        handleAction(action)
                    }
                    if index < actions.count - 1 {
                        Divider()
                    }
                }
            }
            .background(.thinMaterial)
            .cornerRadius(cornerRadius)
            .frame(width: menuWidth)
            .padding(.top, 12)
            .padding(.leading, 16)  // gap from leading
             // space between roomButton and menu
        }
    }

    func roomButton(for room: RoomModel) -> some View {
        ConversationView(roomModel: room, typingIndicator: "")
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
    
    private func handleAction(_ action: MoreMenuAction) {
        switch action {
        case .markAsRead: onMarkAsRead()
        case .markAsUnread: onMarkAsUnread()
        case .mute: onMute()
        case .unmute: onUnmute()
        case .addToFavorites: onAddToFavorites()
        case .removeFromFavorites: onRemoveFromFavorites()
        case .block: onBlock()
        case .unblock: onUnblock()
        case .deleteChat: onDeleteChat()
        case .lockChat: onLockChat()
        }
        onDismiss()
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(Design.Font.regular(14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .foregroundColor(Design.Color.primaryText.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}
