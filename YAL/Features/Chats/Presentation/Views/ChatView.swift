//
//  ChatView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit
import Combine
import SDWebImageSwiftUI

extension Notification.Name {
    static let scrollToPreviousSearchResult = Notification.Name("scrollToPreviousSearchResult")
    static let scrollToNextSearchResult = Notification.Name("scrollToNextSearchResult")
    static let scrollToBottom = Notification.Name("scrollToBottom")
    static let deepLinkOpenChat = Notification.Name("deepLinkOpenChat")
    static let deepLinkOpenChatDetail = Notification.Name("deepLinkOpenChatDetail")
    static let deepLinkOpenUserDetail = Notification.Name("deepLinkOpenUserDetail")
    static let deepLinkOpenGroup = Notification.Name("deepLinkOpenGroup")
    static let deepLinkOpenProfile = Notification.Name("deepLinkOpenProfile")
    static let deepLinkOpenCall = Notification.Name("deepLinkOpenCall")
    static let deepLinkScrollToMessage = Notification.Name("deepLinkScrollToMessage")
    static let deepLinkScrollToMessageProxy = Notification.Name("deepLinkScrollToMessageProxy")
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = ChatLayout.inputBarBottomPad
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = ChatLayout.inputBarBottomPad
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct PendingAttachment: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let size: Int64?
    let localPreview: UIImage?
}

// MARK: - Main ChatView
struct ChatView: View {
    @State private var pendingAttachments: [PendingAttachment] = []
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardResponder()
    @State private var inReplyTo: ChatMessageModel? = nil
    @State private var forwardPayload: ForwardPayload?
    @State private var showAddMembers: Bool = false
    @State private var groupParticipants: [ContactLite] = []
    @State private var invitedContacts: [ContactLite] = []

    @State private var showDeleteDialog = false
    @State private var messagePendingDelete: ChatMessageModel? = nil
    @FocusState private var isInputFocused: Bool
    @State private var focusInputBar: Bool = false

    private let selectedRoom: RoomModel
    private let participants: [ContactModel]
    @State private var showImagePicker = false
    @State private var useCamera: Bool = false
    @State private var showFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var showCopiedToast   = false
    @State private var copiedToastMessage = Constants.copiedToclipBoard.rawValue
    @State private var hasStartedGroupChat: Bool = false

    var onDismiss: (() -> Void)?
    var onMessageRead: (() -> Void)?
    var onReturnFromProfile: (() -> Void)?
    
    @State private var isForwarding: Bool = false
    
    @State private var selectedMessage: ChatMessageModel? = nil
    @State private var previousMessage: ChatMessageModel? = nil
    @State private var bubbleFrame: CGRect? = nil
    @State var isSearching: Bool = true
    @State private var searchText: String = ""
    @State private var resultCount = Int(ChatLayout.resultCounts)
    @State private var showNoResultsAlert = false
    @Namespace private var nsPopover
    @State private var showScrollToBottomButton = false
    
    @State private var showUnBlock = false
    
    @State private var showMediaPickerOverlay = false
    
    @State private var allowedFileTypes: [UTType] = {
        var types: [UTType] = []
        return types
    }()
    
    @State private var urlToOpen: String? = nil

    @Binding var navPath: NavigationPath
    @State private var eventId = UUID().uuidString

    init(selectedRoom: RoomModel, navPath: Binding<NavigationPath>, isSearching: Bool = false, onDismiss: (() -> Void)? = nil, onReturnFromProfile: (() -> Void)? = nil) {
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
//        vm.selectedRoom = selectedRoom
        _chatViewModel = StateObject(wrappedValue: vm)
        self.selectedRoom = selectedRoom
        self.participants = selectedRoom.participants
        self._navPath = navPath
        self.onDismiss = onDismiss
        self.onReturnFromProfile = onReturnFromProfile
        self._isSearching = State(initialValue: isSearching)
    }

    // MARK: - Top Bar (Search or Header)
    @ViewBuilder
    private var topBar: some View {
        if isSearching {
            HStack(spacing: ChatLayout.topBarHorizontalPad) {
                Button(action: { isSearching = false; searchText = "" }) {
                    Image(.close)
                        .resizable()
                        .frame(
                            width:  ChatLayout.frmaeHeightWidth,
                            height: ChatLayout.frmaeHeightWidth
                        )
                }
                .padding(.leading, ChatLayout.topBarHorizontalPad)

                SearchContainer(
                    searchText: $searchText,
                    resultCount: $resultCount,
                    onPrevious: {
                        NotificationCenter.default.post(name: .scrollToPreviousSearchResult, object: nil)
                    },
                    onNext: {
                        NotificationCenter.default.post(name: .scrollToNextSearchResult, object: nil)
                    },
                    showNoResultsAlert: $showNoResultsAlert
                )
                .frame(maxWidth: .infinity, maxHeight: ChatLayout.groupPopupAddButtonHeight)
                .background(Color(uiColor: #colorLiteral(
                    red: 0.9404773116, green: 0.940477252,
                    blue: 0.9404773116, alpha: 1
                )))
                .cornerRadius(ChatLayout.searchBarCornerRadius)
            }
            .padding(.horizontal, ChatLayout.topBarHorizontalPad)
            .padding(.vertical, ChatLayout.topBarVerticalPad)

        } else {
            ZStack(alignment: .top) {
                if (CallManager.shared.callState == .ongoing || CallManager.shared.callState == .outgoing),
                   CallManager.shared.currentRoomModel != nil {
                    OngoingCallWidget(
                        participants: participants,
                        callType: (CallManager.shared.isVideoCall
                            ? Constants.chatVideo : Constants.chatVoice).rawValue,
                        callState: CallManager.shared.callState,
                        onJoinCall: {
                            CallManager.shared.presentCall(for: selectedRoom)
                            CallManager.shared.callState = .ongoing
                        }
                    )
                    .padding(.horizontal, ChatLayout.topBarHorizontalPad)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(ChatLayout.zIndexValue)
                }
            }

            HStack {
                ChatHeaderSection(
                    selectedRoom: selectedRoom,
                    participants: participants,
                    onDismiss: { onDismiss?(); dismiss() },
                    onHeaderTap: {
                        chatViewModel.sharedMedia()
                        if selectedRoom.isGroup {
                            $navPath.wrappedValue.append(NavigationTarget.groupDetails(
                                room: selectedRoom,
                                currentUser: chatViewModel.currentUser,
                                sharedMedia: chatViewModel.sharedMediaPayload
                            ))
                        } else {
                            $navPath.wrappedValue.append(NavigationTarget.userDetails(
                                room: selectedRoom,
                                user: chatViewModel.currentUser,
                                sharedMedia: chatViewModel.sharedMediaPayload
                            ))
                        }
                    },
                    onVideoCallAction: {
                        guard !selectedRoom.isGroup else { return }
                        chatViewModel.currentRoomId = selectedRoom.id
                        chatViewModel.sendCallMessage(
                            callState: .outgoing, isVideo: true, eventId: eventId
                        ) { result in
                            if case .success(let newEventId) = result {
                                eventId = newEventId
                                CallManager.shared.eventId = newEventId
                                CallManager.shared.updateCallStatus()
                            }
                        }
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.isVideoCall = true
                    },
                    onVoiceCallAction: {
                        guard !selectedRoom.isGroup else { return }
                        chatViewModel.currentRoomId = selectedRoom.id
                        chatViewModel.sendCallMessage(
                            callState: .outgoing, isVideo: false, eventId: eventId
                        ) { result in
                            if case .success(let newEventId) = result {
                                eventId = newEventId
                                CallManager.shared.eventId = newEventId
                                CallManager.shared.updateCallStatus()
                            }
                        }
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.isVideoCall = false
                    },
                    onMenuAction: {}
                )
            }
        }
    }

    // MARK: - Empty State Overlay
    @ViewBuilder
    private var emptyStateOverlay: some View {
        if chatViewModel.messages.isEmpty && !isSearching {
            VStack {
                if !selectedRoom.isGroup {
                    VStack(spacing: UIConstants.Layout.tightSpacing + 2) {
                        Text(Constants.ronaldhasnotMsged.rawValue)
                            .font(Design.ChatTextStyles.emptyStateHeadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text(Constants.chatStartTheConversation.rawValue)
                            .font(Design.ChatTextStyles.emptyStateSubtitle)
                            .foregroundColor(.white.opacity(UIConstants.Opacity.high))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ChatLayout.notAMemberHPad)
                    .padding(.top, ChatLayout.groupPopupTopSpacer - 30)
                }

                if selectedRoom.isGroup && !hasStartedGroupChat {
                    GroupCreationPopup(
                        groupImage: selectedRoom.avatarUrl ?? "",
                        memberCount: selectedRoom.participants.count,
                        onStartChat: { hasStartedGroupChat = true; focusInputBar = true },
                        onAddMembers: { showAddMembers = true }
                    )
                    .padding(.horizontal, UIConstants.Layout.wideScreenPadding)
                    .padding(.top, UIConstants.Layout.wideScreenPadding)
                }

                Spacer()

                if !selectedRoom.isGroup || !hasStartedGroupChat {
                    ChatSuggestionsView { text, gifURL in
                        chatViewModel.newMessage = text
                        chatViewModel.sendMessage(toRoom: selectedRoom.id, inReplyTo: inReplyTo)
                        if let gifURL {
                            let fileName  = gifURL.lastPathComponent
                            let size      = (try? FileManager.default.attributesOfItem(
                                atPath: gifURL.path)[.size] as? Int) ?? 0
                            let preview   = (try? Data(contentsOf: gifURL)).flatMap(UIImage.init(data:))
                            let attachment = PendingAttachment(
                                fileURL: gifURL, fileName: fileName,
                                mimeType: "image/gif", size: Int64(size),
                                localPreview: preview
                            )
                            chatViewModel.uploadAndSendMediaMessage(
                                fileURL:      attachment.fileURL,
                                fileName:     attachment.fileName,
                                mimeType:     attachment.mimeType,
                                localPreview: attachment.localPreview
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Bar (Forwarding or Input)
    @ViewBuilder
    private var bottomBar: some View {
        if isForwarding {
            HStack {
                Button(action: {
                    isForwarding = false
                    chatViewModel.selectedMessagesToForword.removeAll()
                }) {
                    Text(Constants.cancel.rawValue)
                        .font(Design.Font.bold(14))
                        .padding(.top, UIConstants.Layout.verticalPadding * 2)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Design.Color.blue)
                }
                .buttonStyle(.plain)

                Text("\(chatViewModel.selectedMessagesToForword.count) \(Constants.selected.rawValue)")
                    .font(Design.Font.bold(14))
                    .padding(.top, UIConstants.Layout.verticalPadding * 2)
                    .padding(.vertical, UIConstants.Layout.internalPadding)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Design.Color.blue)

                Button(action: { startForward(for: chatViewModel.selectedMessagesToForword) }) {
                    Text(Constants.forward.rawValue)
                        .font(Design.Font.bold(14))
                        .padding(.top, UIConstants.Layout.verticalPadding * 2)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(Design.Color.blue)
                }
                .buttonStyle(.plain)
            }

        } else if selectedRoom.isLeft {
            NotAMemberBar(
                title:       Constants.cantSendAnyMessage.rawValue,
                description: Constants.youAreNoLongerMember.rawValue
            )
        } else if !selectedRoom.isGroup,
                  let opponentUserId = selectedRoom.opponent?.userId,
                  chatViewModel.getblockedUsers().contains(selectedRoom.id) {
            UnlockUserButton(opponentUserId: opponentUserId) { showUnBlock = true }
        } else {
            if !pendingAttachments.isEmpty {
                AttachmentPreviewBar(pendingAttachments: $pendingAttachments)
            }
            inputBar
        }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: UIConstants.NavBar.zeroSpacing) {
                    topBar

                    // Incoming call widget banner
                    ZStack(alignment: .top) {
                        if CallManager.shared.callState == .incoming,
                           CallManager.shared.currentRoomModel != nil {
                            OngoingCallWidget(
                                participants: participants,
                                callType: (CallManager.shared.isVideoCall
                                    ? Constants.chatVideo : Constants.chatVoice).rawValue,
                                callState: CallManager.shared.callState,
                                onJoinCall: {
                                    CallManager.shared.presentCall(for: selectedRoom)
                                    CallManager.shared.callState = .ongoing
                                }
                            )
                            .padding(.horizontal, ChatLayout.topBarHorizontalPad)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(ChatLayout.zIndexValue)
                        }
                    }
                    .background(Design.Color.appGradient.opacity(UIConstants.Opacity.low))

                    // Messages + overlays
                    ZStack(alignment: .bottom) {
                        MessagesSection(
                            chatViewModel: chatViewModel,
                            selectedRoom: selectedRoom,
                            selectedMessage: $selectedMessage,
                            previousMessage: $previousMessage,
                            bubbleFrame: $bubbleFrame,
                            nsPopover: nsPopover,
                            navPath: $navPath,
                            searchString: $searchText,
                            isForwarding: $isForwarding,
                            resultCount: $resultCount,
                            showNoResultsAlert: $showNoResultsAlert,
                            showScrollToBottomButton: $showScrollToBottomButton,
                            onURLTapped: { urlString in
                                DispatchQueue.main.async { urlToOpen = urlString }
                            }
                        )
                        .environmentObject(chatViewModel)

                        emptyStateOverlay

                        // Scroll-to-bottom FAB
                        if showScrollToBottomButton {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        NotificationCenter.default.post(name: .scrollToBottom, object: nil)
                                    }) {
                                        Image(.chevronDown)
                                            .font(.system(size: 32))
                                            .foregroundColor(Design.Color.blue)
                                            .shadow(radius: 3)
                                    }
                                    .padding(.trailing, ChatLayout.scrollToBottomTrailingPad)
                                    .padding(.bottom,   ChatLayout.scrollToBottomBottomPad)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Copied toast
                        if showCopiedToast {
                            CopiedToastView(message: copiedToastMessage)
                                .padding(.bottom, UIConstants.Layout.verticalPadding * 2)
                                .zIndex(ChatLayout.zIndexValue)
                        }

                        // No-results label
                        if showNoResultsAlert {
                            VStack {
                                Text(Constants.chatNoResultsFound.rawValue)
                                    .foregroundColor(.gray.opacity(UIConstants.Opacity.high))
                                    .font(Design.ChatTextStyles.noResultsLabel)
                                    .frame(width: 128, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.small)
                                            .fill(Color.white)
                                    )
                                    .transition(.opacity)
                                    .padding(.bottom, UIConstants.Layout.verticalPadding)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                        }
                    }

                    bottomBar
                }
                .background(Design.Color.backgroundColor)

                // Unblock confirmation overlay
                .overlay {
                    if showUnBlock {
                        UnblockConfirmationView(
                            userName: selectedRoom.name,
                            onUnblock: {
                                chatViewModel.unbanUser(
                                    userId: selectedRoom.opponent?.userId ?? "",
                                    currentRoomId: selectedRoom.id
                                )
                                chatViewModel.toggleBlockUser(currentRoomId: selectedRoom.id)
                                selectedRoom.isBlocked = false
                                showUnBlock = false
                            },
                            onCancel: { showUnBlock = false }
                        )
                    }
                }
                .onAppear {
                    chatViewModel.enterRoom(room: selectedRoom)
                    // Trigger search if returning from UserProfileView
                    onReturnFromProfile?()
                    NotificationCenter.default.addObserver(
                        forName: Notification.Name("ChatSearchTapped"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        self.isSearching = true
                    }
                }
                .onDisappear {
                    chatViewModel.leaveIfMatches(room: selectedRoom)
                    chatViewModel.audioPlayer.stop()
                }
                .fullScreenCover(isPresented: Binding(
                    get: { urlToOpen != nil },
                    set: { if !$0 { urlToOpen = nil } }
                )) {
                    if let urlString = urlToOpen {
                        WebViewScreen(urlString: urlString)
                    }
                }
                .sheet(item: $forwardPayload, onDismiss: {
                    forwardPayload = nil
                    isForwarding = false
                    chatViewModel.selectedMessagesToForword.removeAll()
                }) { payload in
                    ForwardMessageView(
                        messageToForward: payload.messages,
                        onComplete: {
                            forwardPayload = nil
                            isForwarding = false
                            chatViewModel.selectedMessagesToForword.removeAll()
                        }
                    )
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(source: useCamera ? .camera : .photoLibrary, selectionLimit: 5) { url, fileName, mimeType, fileSize in
                        guard let url, let fileName, let mimeType else { return }
                        
                        if mimeType.hasPrefix("image/") {
                            let preview: UIImage? = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
                            
                            
                            let attachment = PendingAttachment(fileURL: url,
                                                         fileName: fileName,
                                                               mimeType: mimeType,
                                                               size: 0,
                                                         localPreview: preview)
                            DispatchQueue.main.async {
                                pendingAttachments.append(attachment)
                            }

                        } else if mimeType.hasPrefix("video/") {
                            let thumb = videoThumbnail(url: url)

                            let attachment = PendingAttachment(fileURL: url,
                                                         fileName: fileName,
                                                               mimeType: mimeType,
                                                               size: 0,
                                                         localPreview: thumb)
                            DispatchQueue.main.async {
                                pendingAttachments.append(attachment)
                            }
                            
                        }
                    }
                }

                // Add members sheet
                .sheet(isPresented: $showAddMembers) {
                    SelectContactsListView(
                        participants: $groupParticipants,
                        invitedContacts: $invitedContacts,
                        onComplete: { _, _ in
                            showAddMembers = false
                        },
                        onDismiss: {
                            showAddMembers = false
                        }
                    )
                }

                // File importer
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: allowedFileTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let pickedURL = urls.first else { return }

                        // Security scope
                        guard pickedURL.startAccessingSecurityScopedResource() else {
                            print("Couldn't access the file"); return
                        }
                        defer { pickedURL.stopAccessingSecurityScopedResource() }

                        // Copy to a unique temp location (avoid name clashes)
                        let ext = pickedURL.pathExtension
                        let base = pickedURL.deletingPathExtension().lastPathComponent
                        let safeName = "\(base)_\(UUID().uuidString.prefix(8)).\(ext)"
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)

                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: pickedURL, to: tempURL)
                        } catch {
                            print("Copy to temp failed: \(error)")
                            return
                        }

                        // Derive metadata
                        let mime = mimeTypeForFileExtension(ext)
                        let size = fileSizeBytes(at: tempURL)


                        let contentType = (try? tempURL.resourceValues(forKeys: [.contentTypeKey]))?.contentType

                        if let contentType {
                            if contentType.conforms(to: .movie)
                                || contentType.conforms(to: .audiovisualContent)
                                || contentType.conforms(to: .audio) {
                                // Video/Audio: get duration using the non-deprecated API
                                loadDurationSeconds(at: tempURL) { duration in
                                    let preview = contentType.conforms(to: .movie) ? makeVideoThumbnail(url: tempURL) : nil
                                    
                                    
                                    let attachment = PendingAttachment(fileURL: tempURL,
                                                                       fileName: tempURL.lastPathComponent,
                                                                       mimeType: mime,
                                                                       size: size,
                                                                       localPreview: preview)
                                    DispatchQueue.main.async {
                                        pendingAttachments.append(attachment)
                                    }

                                }
                            } else {
                                // Images / Documents (no duration needed)
                                
                                let attachment = PendingAttachment(fileURL: tempURL,
                                                                   fileName: tempURL.lastPathComponent,
                                                                   mimeType: mime,
                                                                   size: size,
                                                                   localPreview: contentType.conforms(to: .image) ? loadImagePreview(from: tempURL) : nil)
                                DispatchQueue.main.async {
                                    pendingAttachments.append(attachment)
                                }
                            }
                        }

                    case .failure(let error):
                        print("File selection error: \(error)")
                    }
                }

                // Keyboard avoidance
                .padding(.bottom, keyboard.currentHeight)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .animation(.easeOut(duration: 0.3), value: keyboard.currentHeight)
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenProfile)) { note in
                    $navPath.wrappedValue.append(NavigationTarget.userDetails(room: selectedRoom, user: chatViewModel.currentUser, sharedMedia: chatViewModel.sharedMediaPayload))
                }
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkScrollToMessage)) { note in
                    if let messageId = note.userInfo?["messageId"] as? String {
                        scrollToMessage(messageId)
                    }
                }
                
                if showMediaPickerOverlay {
                    MediaPickerOverlay(
                        onDismiss: { showMediaPickerOverlay = false },
                        onItemSelected: { type in
                            showMediaPickerOverlay = false
                            handleMediaPickerSelection(type: type)
                        }
                    )
                    .zIndex(999)
                    .padding(.bottom, ChatLayout.mediaOverlayBottomPad)
                    .padding(.horizontal, ChatLayout.mediaOverlayHorizontalPad)
                }

                // Context menu
                if let selected = selectedMessage, let frame = bubbleFrame {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(100)
                        .onTapGesture {
                            selectedMessage = nil
                            previousMessage = nil
                        }

                    CustomContextMenu(
                        message: selected,
                        previousMessage: previousMessage,
                        isSender: selected.sender == selected.currentUserId,
                        members: participants,
                        isGroupChat: selectedRoom.isGroup,
                        nsPopover: nsPopover,
                        bubbleFrame: frame,
                        screenSize: geometry.size,
                        onReply: { message in
                            selectedMessage = nil
                            inReplyTo = message
                        },
                        onCopy: { message in
                            selectedMessage = nil
                            handleCopy(text: message.content)
                            showCopiedToast = true
                        },
                        onForward: { _ in
                            if !isForwarding {
                                chatViewModel.selectedMessagesToForword.removeAll()
                            }
                            isForwarding.toggle()
                        },
                        onDelete: { message in
                            messagePendingDelete = message
                            showDeleteDialog = true
                        },
                        onEmojiSelect: { emoji in
                            if let message = selectedMessage {
                                chatViewModel.sendReaction(to: message, emoji: emoji)
                            }
                        },
                        onDismiss: { selectedMessage = nil },
                        onInfo: { message in
                            selectedMessage = nil
                            navigateToInfoScreen(selectedMessage: message)
                        }
                    )
                    .zIndex(200)
                }

                // Delete dialog
                if showDeleteDialog, let pending = messagePendingDelete {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(299)
                        .onTapGesture {
                            showDeleteDialog = false
                            messagePendingDelete = nil
                        }
                    DeleteMessageDialog(
                        isSender: pending.sender == pending.currentUserId,
                        onDeleteForEveryone: {
                            selectedMessage = nil
                            chatViewModel.deleteMessage(
                                roomId: pending.roomId,
                                eventId: pending.eventId,
                                reason:  Constants.userDeletedTheMessage.rawValue
                            )
                            showDeleteDialog = false
                            messagePendingDelete = nil
                        },
                        onDeleteForMe: {
                            selectedMessage = nil
                            chatViewModel.deleteLocalMessage(
                                roomId: pending.roomId,
                                eventId: pending.eventId
                            )
                            showDeleteDialog = false
                            messagePendingDelete = nil
                        },
                        onCancel: {
                            showDeleteDialog = false
                            messagePendingDelete = nil
                        }
                    )
                    .zIndex(300)
                }
            }
            .padding(.top, ChatLayout.viewTopPad)
            .ignoresSafeArea(edges: [.top, .leading, .trailing])
            .background(Color(Design.Color.darkgrayColor))
        }
        .hideKeyboardOnTap()
        .environmentObject(ScrollIdleCenter.shared)
    }

    // MARK: - Attachment Preview Bar
    struct AttachmentPreviewBar: View {
        @Binding var pendingAttachments: [PendingAttachment]

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ChatLayout.attachmentSpacing) {
                    ForEach(pendingAttachments) { file in
                        ZStack(alignment: .topTrailing) {

                            // MARK: - Preview Thumbnail
                            thumbnail(for: file)
                                .scaledToFill()
                                .frame(
                                    width:  ChatLayout.attachmentThumbnailSize,
                                    height: ChatLayout.attachmentThumbnailSize
                                )
                                .clipped()
                                .background(
                                    RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.small)
                                        .fill(Color.white.opacity(UIConstants.Opacity.low))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.small))

                            // MARK: - Remove Button
                            Button {
                                if let index = pendingAttachments.firstIndex(where: { $0.id == file.id }) {
                                    pendingAttachments.remove(at: index)
                                }
                            } label: {
                                Design.Icons.image(.closeCircle)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                }
                .padding()
            }
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(UIConstants.Layout.Radius.large)
            .padding(.horizontal, UIConstants.Layout.screenPadding)
        }

        // MARK: - Thumbnail Builder
        @ViewBuilder
        func thumbnail(for file: PendingAttachment) -> some View {

            // Show local preview image if available (images/photos)
            if let preview = file.localPreview {
                Image(uiImage: preview).resizable()
            } else if file.mimeType.contains(Constants.chatVideo.rawValue) {
                Image(systemName: "video.fill").foregroundColor(.blue)
            } else if file.mimeType.contains(Constants.chatPdf.rawValue) {
                Image(systemName: "doc.richtext.fill").foregroundColor(.white)
            } else {
                Image(systemName: "doc.fill").foregroundColor(.gray)
            }
        }
    }

    // MARK: - Input Bar
    private var resolvedSenderName: String {
        guard let sender = inReplyTo?.sender,
              let currentUserId = inReplyTo?.currentUserId,
              sender != currentUserId else { return "You" }
        let senderModel = participants.first { $0.userId == sender }
        return senderModel?.fullName ?? senderModel?.phoneNumber ?? "You"
    }

    var inputBar: some View {
        ChatInputBar(
            message: $chatViewModel.newMessage,
            senderName: .constant(resolvedSenderName),
            inReplyTo: $inReplyTo,
            pendingAttachments: $pendingAttachments,
            typingUsers: chatViewModel.typingUsers,
            onSend: {
                if !pendingAttachments.isEmpty {
                    for file in pendingAttachments {
                        chatViewModel.uploadAndSendMediaMessage(
                            fileURL:      file.fileURL,
                            fileName:     file.fileName,
                            mimeType:     file.mimeType,
                            localPreview: file.localPreview
                        )
                    }
                    pendingAttachments.removeAll()
                }
                chatViewModel.sendMessage(toRoom: selectedRoom.id, inReplyTo: inReplyTo)
                inReplyTo = nil
            },
            onSendAudio: { url in
                chatViewModel.uploadAndSendMediaMessage(
                    fileURL:  url,
                    fileName: Constants.chatAudioM4a.rawValue,
                    mimeType: Constants.chatAuidom4a.rawValue
                )
            },
            onImageButtonTap: {
                hideKeyboard()
                showMediaPickerOverlay = true
            },
            onCancelReply: { inReplyTo = nil },
            focusRequested: $focusInputBar
        )
        .background(Design.Color.backgroundColor)
        .padding(.bottom, ChatLayout.inputBarBottomPad)
    }

    // MARK: - Helpers
    private func handleMediaPickerSelection(type: MediaPickerType) {
        switch type {
        case .camera:
            useCamera = true;  showImagePicker = true
        case .gallery:
            useCamera = false; showImagePicker = true
        case .document:
            var types: [UTType] = [.pdf, .plainText, .rtf, .vCard, .data]
            if let docx = UTType(filenameExtension: Constants.chatDoc.rawValue)  { types.append(docx) }
            if let xlsx = UTType(filenameExtension: Constants.chatXlsx.rawValue) { types.append(xlsx) }
            if let pptx = UTType(filenameExtension: Constants.chatPptx.rawValue) { types.append(pptx) }
            if let json = UTType(filenameExtension: Constants.chatJson.rawValue) { types.append(json) }
            if let csv  = UTType(filenameExtension: Constants.chatCsv.rawValue)  { types.append(csv)  }
            allowedFileTypes = types
            showFilePicker   = true
        case .audio:
            allowedFileTypes = [.mp3, .wav]
            showFilePicker   = true
        }
    }

    func scrollToMessage(_ id: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(
                name: .deepLinkScrollToMessageProxy,
                object: nil,
                userInfo: ["messageId": id]
            )
        }
    }

    func handleCopy(text: String) {
        UIPasteboard.general.string = text
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }
    
    func navigateToInfoScreen(selectedMessage: ChatMessageModel) {
        $navPath.wrappedValue.append(NavigationTarget.messageInfo(room: selectedRoom, user: chatViewModel.currentUser, selectedMessage: selectedMessage))

    }
    func startForward(for messages: [ChatMessageModel]) {
        forwardPayload = .init(messages: messages)
    }
}

// MARK: - Chat Header Section
private struct ChatHeaderSection: View {
    let selectedRoom: RoomModel
    let participants: [ContactModel]
    let onDismiss: () -> Void
    let onHeaderTap: () -> Void
    let onVideoCallAction: () -> Void
    let onVoiceCallAction: () -> Void
    let onMenuAction: () -> Void

    var body: some View {
        Button(action: { onHeaderTap() }) {
            
            ChatHeaderView(
                title: selectedRoom.name,
                subtitle: subtitleText(),
                image: avatarURL(),
                color: selectedRoom.randomeProfileColor,
                backAction: {onDismiss()},
                videoCallAction: {onVideoCallAction()},
                voiceCallAction: {onVoiceCallAction()},
                menuAction: {onMenuAction()}
            )
            .background(Color(Design.Color.darkgrayColor))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    func subtitleText() -> String {
        if selectedRoom.isGroup {
            return "\(selectedRoom.participants.count) \(Constants.chatMembers.rawValue)"
        } else {
            return selectedRoom.opponent?.isOnline ?? false
            ? "Online"
            : lastActiveString(
                from: Int64(selectedRoom.opponent?.lastSeen ?? 0),
                isEpoch: false,
                currentlyActive: selectedRoom.opponent?.isOnline ?? false
            )
        }
    }
    
    func avatarURL() -> String? {
        return selectedRoom.avatarUrl
    }
}

// MARK: - Messages Section
struct MessagesSection: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let selectedRoom: RoomModel
    @Binding var selectedMessage: ChatMessageModel?
    @Binding var previousMessage: ChatMessageModel?
    @Binding var bubbleFrame: CGRect?
    
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    @Namespace var bottomID
    var nsPopover: Namespace.ID
    @Binding var navPath: NavigationPath
    
    @Binding var searchString: String
    @Binding var isForwarding: Bool
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @State private var searchResultEventIDs: [String] = []
    @State private var currentSearchIndex: Int = 0
    @Binding var resultCount: Int
    @State private var highlightedEventID: String? = nil
    @Binding var showNoResultsAlert: Bool
    @Binding var showScrollToBottomButton: Bool
    
    var onURLTapped: ((String) -> Void)? = nil

    @State private var didAddObservers = false
    @State private var nextObserver: NSObjectProtocol?
    @State private var prevObserver: NSObjectProtocol?
    @State private var bottomObserver: NSObjectProtocol?
    
    @State private var viewportHeight: CGFloat = 1
    @State private var barProgressState: CGFloat = 0   // 0 bottom → 1 top
    @State private var barThumbState: CGFloat = 0.15   // default thumb size
    
    @State private var visibleIds: Set<String> = []
    @State private var idToAscIndex: [String: Int] = [:]   // eventId -> ascending index
    @State private var ascMessages: [ChatMessageModel] = []

    @State private var isAtBottom  = true
    @State private var userDragging = false
    @State private var overscrollFromBottom: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: ChatLayout.messageSectionSpacing) {
                        // Bottom anchor (list is inverted, so this is visually at top)
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                            .background(
                                GeometryReader { gp in
                                    let bottomMaxY = gp.frame(in: .named("chatScroll")).maxY
                                    Color.clear.preference(key: ScrollOffsetKey.self, value: bottomMaxY)
                                }
                            )
                            .onAppear   { isAtBottom = true;  showScrollToBottomButton = false }
                            .onDisappear{ isAtBottom = false; showScrollToBottomButton = true }
                        
                        // We render sections in *reverse* order and messages in *reverse* order.
                        // After the 180° rotation of the stack, the on-screen order becomes:
                        //   - Days ascending
                        //   - Headers above their messages
                        //   - Messages within a day from oldest → newest.
                        ForEach(chatViewModel.sections, id: \.date) { section in
                            sectionView(section, proxy: proxy)
                        }
                        
                        if chatViewModel.isPagingTop {
                            ProgressView()
                                .padding(.vertical, UIConstants.Layout.verticalPadding - 2)
                                .rotationEffect(.degrees(180))
                        }
                        
                        if selectedMessage != nil {
                            Spacer()
                                .frame(height: ChatLayout.contextMenuSpacerHeight)
                                .transition(.opacity)
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .onChange(of: searchString) { newValue in
                        updateSearchResults(for: newValue)
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: .deepLinkScrollToMessageProxy
                        )
                    ) { note in
                        if let messageId = note.userInfo?["messageId"] as? String {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(messageId, anchor: .center)
                            }
                            highlightMessage(messageId)
                        }
                    }
                    // When the newest message changes (first in descending array),
                    // keep pinned to bottom if the user is already there.
                    .onReceive(chatViewModel.$messages.map(\.count).removeDuplicates()) { _ in
                        guard isAtBottom && !userDragging else {
                            showScrollToBottomButton = true
                            return
                        }
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear    { scrollProxy = proxy; addObserversIfNeeded() }
                    .onDisappear { removeObservers() }
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear { screenWidth = geo.size.width }
                        }
                            .frame(height: 0)
                    )
                    .overlay(
                        Group {
                            if chatViewModel.showNotAMemberBar {
                                ZStack {
                                    Color.black.opacity(UIConstants.Opacity.medium)
                                        .ignoresSafeArea()
                                        .onTapGesture { }
                                    VStack(spacing: UIConstants.Layout.verticalPadding * 2) {
                                        NotAMemberBar(
                                            title:       Constants.chatYouCantreactMessages.rawValue,
                                            description: Constants.youAreNoLongerMember.rawValue
                                        )
                                        
                                        Button(action: {
                                            withAnimation { chatViewModel.showNotAMemberBar = false }
                                        }) {
                                            Text(Constants.chatDismiss.rawValue)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.red)
                                                .cornerRadius(UIConstants.Layout.Radius.medium)
                                        }
                                    }
                                    .padding(.horizontal, UIConstants.Layout.wideScreenPadding)
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    )
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { _ in
                            userDragging = true
                            ScrollIdleCenter.shared.setDragging(true)
                        }
                        .onEnded { _ in
                            userDragging = false
                            ScrollIdleCenter.shared.setDragging(false)
                            if overscrollFromBottom > 0 {
                                withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.9)) {
                                    scrollProxy?.scrollTo(bottomID, anchor: .bottom)
                                }
                            }
                        }
                )
                .coordinateSpace(name: "chatScroll")
                .overlay(
                    GeometryReader { g in
                        Color.clear.preference(key: ViewportHeightKey.self, value: g.size.height)
                    }
                )
                .rotationEffect(.degrees(180))
                .compositingGroup()

                CustomScrollBar(
                    progress: barProgressState,
                    thumbRatio: barThumbState,
                    onDrag: { pTop in
                        guard !ascMessages.isEmpty else { return }
                        let idx = Int(pTop * CGFloat(ascMessages.count - 1))
                        let target = ascMessages[idx].eventId
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrollProxy?.scrollTo(target, anchor: .center)
                        }
                    }
                )
                .padding(.trailing, 2)
                .padding(.vertical, UIConstants.Layout.tightSpacing)
                .zIndex(1000)
            }
            .onReceive(chatViewModel.visibleMessageIDs) { visibleIds = $0 }
            .onReceive(chatViewModel.$messages) { _ in
                ascMessages = chatViewModel.messages.sorted { $0.timestamp < $1.timestamp }
                idToAscIndex = ascMessages.enumerated().reduce(into: [:]) {
                    $0[$1.element.eventId] = $1.offset
                }
                recalcScrollBar()
            }
            .onChange(of: visibleIds) { _ in recalcScrollBar() }
            .background(Design.Color.backgroundColor)
            .onPreferenceChange(ViewportHeightKey.self) { viewportHeight = $0 }
            .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                overscrollFromBottom = max(viewportHeight - maxY, 0)
            }
        }
        .onPreferenceChange(MessageBubbleAnchorKey.self) { value in
            bubbleFrame = value
        }
    }
}

// MARK: - MessagesSection Helpers
extension MessagesSection {
    // Oldest message in the entire list (by timestamp)
    private var oldestMessageId: String? {
        chatViewModel.messages.min(by: { $0.timestamp < $1.timestamp })?.eventId
    }
    
    // Break large inner expression into a smaller section builder
    @ViewBuilder
    private func sectionView(_ section: MessageSection, proxy: ScrollViewProxy) -> some View {
        ForEach(section.messages, id: \.eventId) { message in
            messageRow(message, section: section, proxy: proxy)
        }
        
        // Date header (will appear ABOVE its messages on screen after inversion)
        Text(section.title)
            .font(Design.ChatTextStyles.sectionDateLabel)
            .foregroundColor(.gray)
            .padding(.vertical, UIConstants.Layout.tightSpacing)
            .rotationEffect(.degrees(180))
    }
    
    // And each message row into its own builder
    @ViewBuilder
    private func messageRow(
        _ message: ChatMessageModel,
        section: MessageSection,
        proxy: ScrollViewProxy
    ) -> some View {
        let previous = previousMessage(in: section, for: message)
        let isHighlighted = message.eventId == highlightedEventID
        
        Group {
            MessageView(
                message: message,
                previousMessage: previous,
                isGroupChat: selectedRoom.isGroup,
                members: selectedRoom.participants,
                screenWidth: screenWidth,
                onDownloadNeeded: { chatViewModel.fetchMedia(for: $0) },
                onMessageRead: {
                    chatViewModel.markMessageAsRead(roomId: selectedRoom.id, eventId: $0.eventId)
                },
                onLongPress: {
                    if selectedRoom.isLeft {
                        withAnimation { chatViewModel.showNotAMemberBar = true }
                    } else if message.content != thisMessageWasDeleted {
                        hideKeyboard()
                        selectedMessage = $0
                        previousMessage = previous
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(message.eventId, anchor: .center)
                        }
                    }
                },
                onScrollToMessage: { eventId in
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(eventId, anchor: .bottom)
                        }
                    }
                },
                selectedEventId: selectedMessage?.eventId,
                navPath: $navPath,
                selectedRoom: selectedRoom,
                isForwarding: isForwarding,
                onToggleChange: { chatViewModel.toggleMessageSelection() },
                onURLTapped: onURLTapped
            )
            .matchedGeometryIf(
                selectedMessage != nil,
                id: message.eventId,
                in: nsPopover,
                properties: .frame,
                anchor: .topLeading,
                isSource: true
            )
            .background(
                Group {
                    if isHighlighted {
                        Design.Color.blueGradient.opacity(UIConstants.Opacity.high)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .padding(.bottom, ChatLayout.messageBottomPad)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: chatViewModel.typingUsers)
        .id(message.eventId)
        .onAppear {
            chatViewModel.rowAppeared(message.eventId)
            if showScrollToBottomButton, message.eventId == oldestMessageId {
                chatViewModel.loadOlderIfNeeded()
            }
        }
        .onDisappear { chatViewModel.rowDisappeared(message.eventId) }
        .rotationEffect(.degrees(180))
    }

    func highlightMessage(_ id: String) {
        highlightedEventID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            highlightedEventID = nil
        }
    }
    
    func scrollToMessage(eventID: String, animated: Bool = true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if animated {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(eventID, anchor: .bottom)
                }
            } else {
                scrollProxy?.scrollTo(eventID, anchor: .bottom)
            }
        }
    }

    private func addObserversIfNeeded() {
        guard !didAddObservers else { return }
        prevObserver = NotificationCenter.default.addObserver(
            forName: .scrollToPreviousSearchResult, object: nil, queue: .main
        ) { _ in scrollToPreviousSearchResult() }
        nextObserver = NotificationCenter.default.addObserver(
            forName: .scrollToNextSearchResult, object: nil, queue: .main
        ) { _ in scrollToNextSearchResult() }
        bottomObserver = NotificationCenter.default.addObserver(
            forName: .scrollToBottom, object: nil, queue: .main
        ) { _ in
            if let proxy = scrollProxy {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
        didAddObservers = true
    }

    private func removeObservers() {
        if let o = prevObserver   { NotificationCenter.default.removeObserver(o); prevObserver   = nil }
        if let o = nextObserver   { NotificationCenter.default.removeObserver(o); nextObserver   = nil }
        if let o = bottomObserver { NotificationCenter.default.removeObserver(o); bottomObserver = nil }
        didAddObservers = false
    }

    private func updateSearchResults(for text: String) {
        guard !text.isEmpty else {
            searchResultEventIDs = []
            currentSearchIndex   = 0
            resultCount          = 0
            highlightedEventID   = nil
            showNoResultsAlert   = false
            return
        }
        let filtered         = chatViewModel.messages.filter { $0.isSelectedFromSearch(searchString: text) }
        searchResultEventIDs = filtered.map { $0.eventId }
        currentSearchIndex   = 0
        resultCount          = searchResultEventIDs.count
        highlightedEventID   = searchResultEventIDs.first
        showNoResultsAlert   = (resultCount == 0)
        if let firstID = searchResultEventIDs.first { scrollToMessage(eventID: firstID) }
    }

    private func scrollToPreviousSearchResult() {
        guard !searchResultEventIDs.isEmpty else { return }
        currentSearchIndex = max(currentSearchIndex - 1, 0)
        let id = searchResultEventIDs[currentSearchIndex]
        highlightedEventID = id
        scrollToMessage(eventID: id)
    }

    private func scrollToNextSearchResult() {
        guard !searchResultEventIDs.isEmpty else { return }
        currentSearchIndex = min(currentSearchIndex + 1, searchResultEventIDs.count - 1)
        let id = searchResultEventIDs[currentSearchIndex]
        highlightedEventID = id
        scrollToMessage(eventID: id)
    }

    func shouldShowSenderInfo(current: ChatMessageModel, previous: ChatMessageModel?) -> Bool {
        guard let previous = previous else { return true }
        return previous.sender != current.sender
    }

    private func previousMessage(in section: MessageSection, for message: ChatMessageModel) -> ChatMessageModel? {
        guard let idx = section.messages.firstIndex(where: { $0.eventId == message.eventId }),
              idx > 0 else { return nil }
        return section.messages[idx - 1]
    }

    @ViewBuilder
    private func MessageView(
        message: ChatMessageModel,
        previousMessage: ChatMessageModel?,
        isGroupChat: Bool,
        members: [ContactModel],
        screenWidth: CGFloat,
        onDownloadNeeded: @escaping (ChatMessageModel) -> Void,
        onMessageRead: @escaping (ChatMessageModel) -> Void,
        onLongPress: @escaping (ChatMessageModel) -> Void,
        onScrollToMessage: ((String) -> Void)? = nil,
        selectedEventId: String? = nil,
        navPath: Binding<NavigationPath>,
        selectedRoom: RoomModel,
        isForwarding: Bool = false,
        onToggleChange: (@escaping () -> Void),
        onURLTapped: ((String) -> Void)? = nil
    ) -> some View {
        if message.isReceived {
            let senderModel    = members.first { $0.userId == message.sender }
            let senderName     = senderModel?.fullName ?? senderModel?.phoneNumber
            let senderAvatarURL = senderModel?.avatarURL ?? senderModel?.imageURL
            let showSenderInfo = isGroupChat && (previousMessage?.sender != message.sender)

            ReceiverMessageView(
                message: message,
                isGroupChat: isGroupChat,
                senderName: senderName ?? "",
                senderAvatarURL: senderAvatarURL,
                showSenderInfo: showSenderInfo,
                participantCount: members.count,
                onAvatarTap: {},
                onDownloadNeeded: onDownloadNeeded,
                onTap: {
                    if let callState = message.callState,
                       (callState == .ongoing || callState == .outgoing || callState == .incoming),
                       (message.msgType == Constants.mVoiceCall.rawValue
                        || message.msgType == Constants.mVideoCall.rawValue) {
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.eventId   = message.eventId
                        CallManager.shared.callState = .ongoing
                        CallManager.shared.isVideoCall = message.msgType != Constants.mVoiceCall.rawValue
                    }
                },
                onLongPress: { onLongPress(message) },
                onMessageRead: { onMessageRead(message) },
                onScrollToMessage: { onScrollToMessage?($0) },
                onCallBack: {
                    if let callState = message.callState,
                       (callState == .ongoing || callState == .outgoing || callState == .incoming),
                       (message.msgType == Constants.mVoiceCall.rawValue
                        || message.msgType == Constants.mVideoCall.rawValue) {
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.eventId   = message.eventId
                        CallManager.shared.callState = .ongoing
                        CallManager.shared.isVideoCall = message.msgType != Constants.mVoiceCall.rawValue
                    }
                },
                onURLTapped: onURLTapped,
                onToggleChange: { onToggleChange() },
                selectedEventId: selectedEventId,
                searchText: searchString,
                isForwarding: isForwarding
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, screenWidth * ChatLayout.receiverTrailingPadRatio)

        } else {
            let senderModel = members.first { $0.userId == message.sender }
            let senderName  = senderModel?.fullName ?? senderModel?.phoneNumber

            SenderMessageView(
                message: message,
                senderName: senderName ?? "",
                participantCount: members.count,
                onDownloadNeeded: onDownloadNeeded,
                onTap: {
                    if let callState = message.callState,
                       (callState == .ongoing || callState == .outgoing || callState == .incoming),
                       (message.msgType == Constants.mVoiceCall.rawValue
                        || message.msgType == Constants.mVideoCall.rawValue) {
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.eventId   = message.eventId
                        CallManager.shared.callState = .ongoing
                        CallManager.shared.isVideoCall = message.msgType != Constants.mVoiceCall.rawValue
                    }
                },
                onLongPress: { onLongPress(message) },
                onScrollToMessage: { onScrollToMessage?($0) },
                onCallBack: {
                    if let callState = message.callState,
                       (callState == .ongoing || callState == .outgoing || callState == .incoming),
                       (message.msgType == Constants.mVoiceCall.rawValue
                        || message.msgType == Constants.mVideoCall.rawValue) {
                        CallManager.shared.presentCall(for: selectedRoom)
                        CallManager.shared.eventId   = message.eventId
                        CallManager.shared.callState = .ongoing
                        CallManager.shared.isVideoCall = message.msgType != Constants.mVoiceCall.rawValue
                    }
                },
                selectedEventId: selectedEventId,
                searchText: searchString,
                isForwarding: isForwarding,
                onToggleChange: { onToggleChange() },
                senderImage: loadProfileImage(),
                onURLTapped: onURLTapped
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, ChatLayout.senderLeadingPad)
        }
    }

    private func loadProfileImage() -> String {
        if let profile = Storage.get(
            for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let imageUrlString = profile.profileImageUrl {
            return imageUrlString
        }
        return ""
    }

    private func recalcScrollBar() {
        guard !ascMessages.isEmpty else { barProgressState = 0; barThumbState = 1; return }
        let idxs = visibleIds.compactMap { idToAscIndex[$0] }
        guard !idxs.isEmpty else { return }
        let center = CGFloat(idxs.reduce(0, +)) / CGFloat(idxs.count)
        let total  = CGFloat(max(ascMessages.count - 1, 1))
        barProgressState = 1 - (center / total)
        let approxVisible = CGFloat(idxs.count)
        barThumbState = min(max(approxVisible / CGFloat(ascMessages.count), 0.05), 1.0)
    }
}

// MARK: - Supporting Views

struct NotAMemberBar: View {
    let title: String
    let description: String

    var body: some View {
        VStack {
            VStack {
                Text(title)
                Text(description)
            }
            .multilineTextAlignment(.center)
            .font(Design.ChatTextStyles.notAMemberTitle)
            .foregroundColor(Design.Color.primaryTextColor)
            .frame(maxWidth: .infinity)
            .padding(.top,        UIConstants.Layout.verticalPadding * 2)
            .padding(.bottom,     UIConstants.Layout.wideScreenPadding)
            .padding(.horizontal, ChatLayout.notAMemberHPad)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.large))
    }
}

struct MessageSection: Identifiable {
    let date: Date
    let title: String
    let messages: [ChatMessageModel]
    var id: Date { date }
}

struct DeleteMessageDialog: View {
    let isSender: Bool
    var onDeleteForEveryone: () -> Void
    var onDeleteForMe: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Layout.internalPadding) {
            Text("Delete Message?")
                .foregroundColor(Design.Color.primaryTextColor)
                .font(Design.ChatTextStyles.deleteDialogTitle)
                .padding([.top, .leading], UIConstants.Layout.screenPadding)
            VStack {
                if isSender {
                    actionButton(label: Constants.chatDeleteForEveryOne.rawValue) { onDeleteForEveryone() }
                }
                actionButton(label: Constants.chatDeleteForMe.rawValue) { onDeleteForMe() }
                actionButton(label: Constants.cancel.rawValue)           { onCancel() }
            }
            .padding(.bottom, UIConstants.Layout.smallBottomPadding - 1)
        }
        .background(Color(Design.Color.darkgrayColor))
        .cornerRadius(UIConstants.Layout.Radius.large)
        .padding(UIConstants.Layout.wideScreenPadding)
    }
}

private func actionButton(label: String, action: @escaping () -> Void) -> some View {
    HStack {
        Spacer()
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 0) {
                Spacer()
                Text(label)
                    .font(Design.ChatTextStyles.deleteDialogAction)
                    .padding(.trailing, UIConstants.Layout.screenPadding)
                    .padding(.vertical,  UIConstants.Layout.tightSpacing + 2)
            }
            .foregroundColor(Design.Color.primaryTextColor)
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
}

struct SearchContainer: View {
    @Binding var searchText: String
    @Binding var resultCount: Int
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    @Binding var showNoResultsAlert: Bool
    
    var body: some View {
        HStack(spacing: ChatLayout.topBarHorizontalPad) {
            Image(.tFsearch)
                .resizable()
                .frame(width: ChatLayout.searchIconSize, height: ChatLayout.searchIconSize)
                .padding(.leading, ChatLayout.topBarHorizontalPad)

            TextField(Constants.search.rawValue, text: $searchText, onCommit: {
                hideKeyboard()
                withAnimation { showNoResultsAlert = resultCount == 0 }
            })
            .textFieldStyle(PlainTextFieldStyle())
            .font(Design.ChatTextStyles.inputPlaceholder)
            .foregroundColor(.black)
            .background(Color.clear)
            .autocapitalization(.none)
            .disableAutocorrection(true)

            if !searchText.isEmpty {
                SearchResultCountView(
                    resultCount: $resultCount,
                    onPrevious: onPrevious,
                    onNext: onNext,
                    showNoResultsAlert: $showNoResultsAlert
                )
                .padding(.trailing, ChatLayout.topBarHorizontalPad)
            }
        }
        .frame(height: ChatLayout.searchBarHeight - 4)
    }
}

struct SearchResultCountView: View {
    @Binding var resultCount: Int
    @State private var currentIndex: Int = 1
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    @Binding var showNoResultsAlert: Bool

    var body: some View {
        HStack(spacing: UIConstants.Layout.verticalPadding) {
            Button(action: {
                guard currentIndex > 1 else { return }
                currentIndex -= 1
                onPrevious?()
            }) {
                Design.Icons.image(.chevronUp)
                    .foregroundColor(.black)
                    .imageScale(.medium)
                    .frame(
                        width:  ChatLayout.mediaOverlayHorizontalPad,
                        height: ChatLayout.mediaOverlayHorizontalPad
                    )
            }
            .disabled(showNoResultsAlert)
            .opacity(showNoResultsAlert ? UIConstants.Opacity.medium : 1.0)

            Text("\(min(currentIndex, resultCount)) / \(resultCount)")
                .font(Design.ChatTextStyles.searchCounter)
                .foregroundColor(.black)

            Button(action: {
                guard currentIndex < resultCount else { return }
                currentIndex += 1
                onNext?()
            }) {
                Design.Icons.image(.chevronDown)
                    .foregroundColor(.black)
                    .imageScale(.medium)
                    .frame(
                        width:  ChatLayout.mediaOverlayHorizontalPad,
                        height: ChatLayout.mediaOverlayHorizontalPad
                    )
            }
            .disabled(showNoResultsAlert)
            .opacity(showNoResultsAlert ? UIConstants.Opacity.medium : 1.0)
        }
        frame(width: ChatLayout.searchCounterWidth, height: ChatLayout.searchCounterHeight)
        .background(Color(uiColor: #colorLiteral(
            red: 0.8156862745, green: 0.8470588235,
            blue: 0.9294117647, alpha: 1
        )))
        .cornerRadius(ChatLayout.searchCounterCornerRadius)
    }
}

struct UnlockUserButton: View {
    var opponentUserId: String
    var action: () -> Void

    var body: some View {
        VStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            }) {
                HStack(spacing: UIConstants.Layout.internalPadding) {
                    Image(.shieldCrossBlue)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width:  UIConstants.Layout.Height.iconAction + 4,
                            height: UIConstants.Layout.Height.iconAction + 4
                        )
                    Text(Constants.unBlockUser.rawValue)
                        .font(Design.Font.bold(16))
                }
                .padding(.top,      UIConstants.Layout.verticalPadding * 2)
                .padding(.vertical, UIConstants.Layout.internalPadding)
                .frame(maxWidth: .infinity)
                .foregroundColor(Design.Color.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

struct MediaPickerOverlay: View {
    var onDismiss: () -> Void
    var onItemSelected: (MediaPickerType) -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()
                VStack {
                    HStack(spacing: ChatLayout.mediaPickerSpacing) {
                        MediaPickerButton(icon: "camera",   title: Constants.chatCamera.rawValue)   { onItemSelected(.camera)   }
                        MediaPickerButton(icon: "gallery",  title: Constants.chatGallery.rawValue)  { onItemSelected(.gallery)  }
                        MediaPickerButton(icon: "document", title: Constants.chatDocument.rawValue) { onItemSelected(.document) }
                        MediaPickerButton(icon: "music",    title: Constants.chatAuio.rawValue)     { onItemSelected(.audio)    }
                    }
                }
                .padding(.top,    UIConstants.Layout.sectionBottomPadding - 6)
                .padding(.bottom, UIConstants.Layout.sectionBottomPadding - 6)
                .frame(maxWidth: .infinity)
                .background(Color(Design.Color.darkgrayColor))
                .clipShape(CustomRoundedCornersShape(
                    radius: ChatLayout.mediaPickerCornerRadius,
                    roundedCorners: [.topRight, .topLeft, .bottomLeft, .bottomRight]
                ))
                .shadow(radius: 5)
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: UUID())
        }
    }
}

struct MediaPickerButton: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: UIConstants.Layout.tightSpacing + 2) {
            Button(action: action) {
                Rectangle()
                    .fill(Design.Color.black)
                    .cornerRadius(UIConstants.Layout.Radius.medium)
                    .frame(
                        width:  ChatLayout.mediaPickerButtonSize,
                        height: ChatLayout.mediaPickerButtonSize
                    )
                    .overlay(Image(icon).font(.system(size: 24)))
            }
            Text(title)
                .font(Design.ChatTextStyles.mediaPickerLabel)
                .foregroundColor(.gray)
        }
    }
}

enum MediaPickerType {
    case camera, gallery, document, audio
}

private struct URLWrapper: Identifiable {
    let id = UUID()
    let urlString: String
}

struct CustomScrollBar: View {
    var progress: CGFloat
    var thumbRatio: CGFloat
    var onDrag: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            let trackH   = geo.size.height
            let thumbH   = max(ChatLayout.scrollBarMinThumbHeight, trackH * thumbRatio)
            let clampedP = min(max(progress, 0), 1)
            let y        = (trackH - thumbH) * (1 - clampedP)

            ZStack(alignment: .top) {
                Capsule().fill(Color.clear)
                Capsule()
                    .fill(.ultraThickMaterial)
                    .frame(height: thumbH)
                    .offset(y: y)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let y = min(max(v.location.y - thumbH / 2, 0), trackH - thumbH)
                                let p = y / max(trackH - thumbH, 1)
                                onDrag(p)
                            }
                    )
            }
        }
        .frame(width: ChatLayout.scrollBarWidth)
        .cornerRadius(ChatLayout.scrollBarWidth / 2)
        .shadow(radius: 1, y: 1)
    }
}

struct SuggestionItem: View {
    let index: Int
    let image: String
    let text: String
    let onTap: (_ text: String, _ gifURL: URL?) -> Void

    var body: some View {
        ZStack {
            Text(text)
                .font(Design.ChatTextStyles.suggestionChip)
                .foregroundColor(.white.opacity(UIConstants.Opacity.high))
                .padding(.horizontal, UIConstants.Layout.screenPadding - 4)
                .padding(.vertical,   UIConstants.Layout.internalPadding)
                .background(
                    RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.small, style: .continuous)
                        .fill(Color(Design.Color.darkgrayColor))
                )
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                if index == 1 { Spacer() }
                WebImage(url: Bundle.main.url(forResource: image, withExtension: "gif"))
                    .resizable()
                    .scaledToFit()
                    .frame(height: ChatLayout.suggestionGifHeight)
                    .offset(y: ChatLayout.suggestionGifOffsetY)
                if index == 0 { Spacer() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap(text, Bundle.main.url(forResource: image, withExtension: "gif"))
        }
    }
}

struct ChatSuggestionsView: View {
    let onSend: (_ text: String, _ gifURL: URL?) -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: UIConstants.Layout.formSpacing) {
                HStack(alignment: .center, spacing: UIConstants.Layout.verticalPadding - 2) {
                    SuggestionItem(
                        index: 0,
                        image: "b30bc5321dd0666e3744f7965cbe5439e7bd8be5",
                        text:  Constants.howareyouRonald.rawValue,
                        onTap: onSend
                    )
                    
                    SuggestionItem(
                        index: 1,
                        image: "c1fd086ee7f3c90c1b62fe9fac03632e77427c33",
                        text:  Constants.howItsGoing.rawValue,
                        onTap: onSend
                    )
                }
                
                SuggestionItem(
                    index: 2,
                    image: "4245c5d419e87cba5394436b84f1af9ad23ce9ca",
                    text:  Constants.heyRonald.rawValue,
                    onTap: onSend
                )
            }
        }
    }
}

struct GroupCreationPopup: View {
    let groupImage: String
    let memberCount: Int
    let onStartChat: () -> Void
    let onAddMembers: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: ChatLayout.groupPopupTopSpacer)
            popupContent
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var popupContent: some View {
        VStack(spacing: UIConstants.Layout.internalPadding) {
            if let url = URL(string: groupImage), !groupImage.isEmpty {
                WebImage(url: url)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width:  ChatLayout.groupPopupAvatarSize,
                        height: ChatLayout.groupPopupAvatarSize
                    )
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(red: 0.32, green: 0.38, blue: 0.43))
                    .frame(
                        width:  ChatLayout.groupPopupAvatarSize,
                        height: ChatLayout.groupPopupAvatarSize
                    )
                    .overlay(
                        Design.Icons.image(.groupFill)
                            .font(Design.ChatTextStyles.fontSizeText)
                            .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
                    )
            }

            VStack(spacing: UIConstants.Layout.tightSpacing) {
                Text(Constants.uCreatedThisGroup.rawValue)
                    .font(Design.ChatTextStyles.groupPopupTitle)
                    .foregroundColor(.white)
                Text("\(Constants.chatGroup.rawValue) \(memberCount) \(Constants.chatMember.rawValue)\(memberCount == 1 ? "" : "s")")
                    .font(Design.ChatTextStyles.groupMemberCount)
                    .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
            }

            VStack(spacing: UIConstants.Layout.internalPadding) {
                Button(action: onStartChat) {
                    Text(Constants.startChat.rawValue)
                        .font(Design.ChatTextStyles.groupStartButton)
                        .foregroundColor(.white)
                        .frame(
                            width:  ChatLayout.groupPopupButtonWidth,
                            height: ChatLayout.groupPopupButtonHeight
                        )
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.46, green: 0.56, blue: 1),
                                    Color(red: 0.63, green: 0.49, blue: 0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(ChatLayout.groupPopupCornerRadius)
                }

                Button(action: onAddMembers) {
                    Text(Constants.addMembers.rawValue)
                        .font(Design.ChatTextStyles.groupAddButton)
                        .foregroundColor(.black.opacity(UIConstants.Opacity.high))
                        .frame(
                            width:  ChatLayout.groupPopupButtonWidth,
                            height: ChatLayout.groupPopupAddButtonHeight
                        )
                        .background(Color.white)
                        .cornerRadius(ChatLayout.groupPopupCornerRadius)
                }
            }
        }
        .padding(.top,        UIConstants.Layout.internalPadding)
        .padding(.bottom,     UIConstants.Layout.internalPadding)
        .padding(.horizontal, UIConstants.Layout.verticalPadding - 2)
        .frame(width: ChatLayout.groupPopupWidth, height: ChatLayout.groupPopupHeight)
        .background(
            RoundedRectangle(cornerRadius: ChatLayout.groupPopupCornerRadius)
                .fill(Color(Design.Color.darkgrayColor))
        )
    }
}
