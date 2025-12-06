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

private struct TopEdgeKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = nextValue() }
}

private struct TopEdgeWatcher: View {
    let threshold: CGFloat
    let onChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("chatScroll")).minY
            Color.clear
                .preference(key: TopEdgeKey.self, value: minY >= threshold)
//                .onChange(of: minY) { v in
//                    print("TopEdgeWatcher minY:", v) // remove later
//                }
        }
        .frame(height: 1)
        .onPreferenceChange(TopEdgeKey.self, perform: onChange)
    }
}

// MARK: - Main ChatView
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardResponder()
    @State private var inReplyTo: ChatMessageModel? = nil
    @State private var forwardPayload: ForwardPayload?

    @State private var showDeleteDialog = false
    @State private var messagePendingDelete: ChatMessageModel? = nil

    private let selectedRoom: RoomModel
    private let participants: [ContactModel]
    @State private var showImagePicker = false
    @State private var useCamera: Bool = false
    @State private var showFilePicker = false
    @State private var selectedImage: UIImage?
    @State private var showCopiedToast = false
    @State private var copiedToastMessage = "Copied to Clipboard"
    
    var onDismiss: (() -> Void)?
    var onMessageRead: (() -> Void)?
    var onReturnFromProfile: (() -> Void)?
    
    @State private var isForwarding: Bool = false
    
    @State private var selectedMessage: ChatMessageModel? = nil
    @State private var previousMessage: ChatMessageModel? = nil
    @State private var bubbleFrame: CGRect? = nil
    @State var isSearching: Bool = true
    @State private var searchText: String = ""
    @State private var resultCount = 5
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

    init(selectedRoom: RoomModel, navPath: Binding<NavigationPath>, isSearching: Bool = false, onDismiss: (() -> Void)? = nil, onReturnFromProfile: (() -> Void)? = nil) {
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        vm.selectedRoom = selectedRoom
        _chatViewModel = StateObject(wrappedValue: vm)
        self.selectedRoom = selectedRoom
        self.participants = selectedRoom.participants
        self._navPath = navPath
        self.onDismiss = onDismiss
        self.onReturnFromProfile = onReturnFromProfile
        self._isSearching = State(initialValue: isSearching)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    if isSearching {
                        HStack(spacing: 8) {
                            Button(action: {
                                isSearching = false
                                searchText = ""
                            }) {
                                Image("close")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.leading, 8)
                            SearchContainer(searchText: $searchText, resultCount: $resultCount, onPrevious: { NotificationCenter.default.post(name: .scrollToPreviousSearchResult, object: nil) }, onNext: { NotificationCenter.default.post(name: .scrollToNextSearchResult, object: nil) }, showNoResultsAlert: $showNoResultsAlert)
                                .frame(maxWidth: .infinity, maxHeight: 44)
                                .background(Color(uiColor: #colorLiteral(red: 0.9404773116, green: 0.940477252, blue: 0.9404773116, alpha: 1)))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    } else {
                        ChatHeaderSection(
                            selectedRoom: selectedRoom,
                            participants: participants,
                            onDismiss: {
                                onDismiss?()
                                dismiss()
                            },
                            onHeaderTap: {
                                chatViewModel.sharedMedia()
                                if selectedRoom.isGroup {
                                    $navPath.wrappedValue.append(NavigationTarget.groupDetails(room: selectedRoom, currentUser: chatViewModel.currentUser, sharedMedia: chatViewModel.sharedMediaPayload))
                                } else {
                                    $navPath.wrappedValue.append(NavigationTarget.userDetails(room: selectedRoom, user: chatViewModel.currentUser, sharedMedia: chatViewModel.sharedMediaPayload))
                                }
                            }
                        )
                    }
                    ZStack(alignment: .bottom) {
                        MessagesSection(
                            chatViewModel: chatViewModel,
                            selectedRoom: selectedRoom,
                            selectedMessage: $selectedMessage,
                            previousMessage: $previousMessage,
                            bubbleFrame: $bubbleFrame,
                            nsPopover: nsPopover,
                            searchString: $searchText,
                            isForwarding: $isForwarding,
                            resultCount: $resultCount,
                            showNoResultsAlert: $showNoResultsAlert,
                            showScrollToBottomButton: $showScrollToBottomButton,
                            onURLTapped: { urlString in
                                // Use async dispatch to ensure view hierarchy is ready
                                DispatchQueue.main.async {
                                    urlToOpen = urlString
                                }
                            }
                        )
                        .environmentObject(chatViewModel)
                        
                        if showScrollToBottomButton {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        NotificationCenter.default.post(name: .scrollToBottom, object: nil)
                                    }) {
                                        Image("chevron-down")
                                            .font(.system(size: 32))
                                            .foregroundColor(Design.Color.blue)
                                            .shadow(radius: 3)
                                    }
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 8)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        if showCopiedToast {
                            CopiedToastView(message: copiedToastMessage)
                                .padding(.bottom, 20)
                                .zIndex(1)
                        }
                        if showNoResultsAlert {
                            VStack {
                                Text("No results found")
                                    .foregroundColor(.gray.opacity(0.8))
                                    .font(Design.Font.regular(12))
                                    .frame(width: 128, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                    )
                                    .transition(.opacity)
                                    .padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                        }
                    }
                    if isForwarding {
                        HStack {
                            Button(action: {
                                self.isForwarding.toggle()
                                self.chatViewModel.selectedMessagesToForword.removeAll()
                            }) {
                                HStack(spacing: 12) {
                                    Text("Cancel")
                                        .font(Design.Font.bold(14))
                                }
                                .padding(.top, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)  // Make the HStack take full width
                                .foregroundColor(Design.Color.blue)
                            }
                            .buttonStyle(.plain)
                            
                            HStack(spacing: 12) {
                                Text("\(chatViewModel.selectedMessagesToForword.count) Selected")
                                    .font(Design.Font.bold(14))
                            }
                            .padding(.top, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)  // Make the HStack take full width
                            .foregroundColor(Design.Color.blue)
                            
                            Button(action: {
                                print(self.chatViewModel.selectedMessagesToForword)
                                self.startForward(for: self.chatViewModel.selectedMessagesToForword)
                            }) {
                                HStack(spacing: 12) {
                                    Text("Forword")
                                        .font(Design.Font.bold(14))
                                }
                                .padding(.top, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)  // Make the HStack take full width
                                .foregroundColor(Design.Color.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        if selectedRoom.isLeft {
                            NotAMemberBar(
                                title: "You can't send any messages,",
                                description: "you are no longer a member."
                            )
                        } else {
                            if !selectedRoom.isGroup {
                                let blockedUsers = chatViewModel.getblockedUsers()
                                
                                if let opponentUserId = selectedRoom.opponent?.userId {
                                    if blockedUsers.contains(selectedRoom.id) {
                                        UnlockUserButton(opponentUserId: opponentUserId) {
                                            showUnBlock = true
                                        }
                                    } else {
                                        inputBar
                                    }
                                } else {
                                    inputBar
                                }
                                
                            } else {
                                inputBar
                            }
                        }
                    }
                }
                .background(Design.Color.chatBackground)
                .overlay{
                    if showUnBlock {
                        UnblockConfirmationView(
                            userName: selectedRoom.name,
                            onUnblock: {
                                chatViewModel.unbanUser(userId: selectedRoom.opponent?.userId ?? "", currentRoomId: selectedRoom.id)
                                chatViewModel.toggleBlockUser(currentRoomId: selectedRoom.id)
                                selectedRoom.isBlocked = false
                                showUnBlock = false
                            },
                            onCancel: { showUnBlock = false }
                        )
                    }
                }
                .onAppear {
                    chatViewModel.setActiveRoom(selectedRoom.id)
                    // Trigger search if returning from UserProfileView
                    onReturnFromProfile?()
                    NotificationCenter.default.addObserver(forName: Notification.Name("ChatSearchTapped"), object: nil, queue: .main) { _ in
                            self.isSearching = true
                        }
                }
                .onDisappear {
                    chatViewModel.leaveIfMatches(selectedRoom.id)
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
                    ImagePicker(source: useCamera ? .camera : .photoLibrary) { url, fileName, mimeType, fileSize in
                        guard let url, let fileName, let mimeType else { return }
                        
                        if mimeType.hasPrefix("image/") {
                            let preview: UIImage? = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
                            chatViewModel.uploadAndSendMediaMessage(
                                fileURL: url,
                                fileName: fileName,
                                mimeType: mimeType,
                                localPreview: preview
                            )
                        } else if mimeType.hasPrefix("video/") {
                            let thumb = videoThumbnail(url: url) // (func provided below)
                            chatViewModel.uploadAndSendMediaMessage(
                                fileURL: url,
                                fileName: fileName,
                                mimeType: mimeType,
                                localPreview: thumb,
                            )
                        }
                    }
                }
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
                                    chatViewModel.uploadAndSendMediaMessage(
                                        fileURL: tempURL,
                                        fileName: tempURL.lastPathComponent,
                                        mimeType: mime,
                                        duration: duration,
                                        size: size,
                                        localPreview: preview
                                    )
                                }
                            } else {
                                // Images / Documents (no duration needed)
                                chatViewModel.uploadAndSendMediaMessage(
                                    fileURL: tempURL,
                                    fileName: tempURL.lastPathComponent,
                                    mimeType: mime,
                                    duration: nil,
                                    size: size,
                                    localPreview: contentType.conforms(to: .image) ? loadImagePreview(from: tempURL) : nil
                                )
                            }
                        }

                    case .failure(let error):
                        print("File selection error: \(error)")
                    }
                }
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
                }

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
                        onForward: { message in
                            if !isForwarding {
                                self.chatViewModel.selectedMessagesToForword.removeAll()
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
                                reason: "User deleted the message"
                            )
                            showDeleteDialog = false
                            messagePendingDelete = nil
                        },
                        onDeleteForMe: {
                            selectedMessage = nil
                            chatViewModel.deleteLocalMessage(eventId: pending.eventId)
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
            .padding(.top, 56)
            .ignoresSafeArea(edges: [.top, .leading, .trailing])
        }
        .hideKeyboardOnTap()
    }
    
    private func handleMediaPickerSelection(type: MediaPickerType) {
        switch type {
        case .camera:
            useCamera = true
            showImagePicker = true
        case .gallery:
            useCamera = false
            showImagePicker = true
        case .document:
            var allowedDocumentTypes: [UTType] {
                var types: [UTType] = [.pdf, .plainText, .rtf, .vCard, .data]
                
                // Word, Excel, PowerPoint
                if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
                if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
                if let pptx = UTType(filenameExtension: "pptx") { types.append(pptx) }
                
                // JSON, CSV
                if let json = UTType(filenameExtension: "json") { types.append(json) }
                if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
                
                return types
            }

            allowedFileTypes = allowedDocumentTypes
            showFilePicker = true
        case .audio:
            allowedFileTypes = [.mp3, .wav]
            showFilePicker = true
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
        
    // MARK: Input Bar
    var inputBar: some View {
        var senderName = "You"
        if let sender = inReplyTo?.sender, let currentUserId = inReplyTo?.currentUserId {
            if sender != currentUserId {
                let senderModel = participants.first { $0.userId == sender }
                senderName = senderModel?.fullName ?? senderModel?.phoneNumber ?? ""
            }
        }
        return ChatInputBar(
            message: $chatViewModel.newMessage,
            senderName: .constant(senderName),
            inReplyTo: $inReplyTo,
            typingUsers: chatViewModel.typingUsers,
            onSend: {
                chatViewModel.sendMessage(toRoom: selectedRoom.id, inReplyTo: inReplyTo)
                inReplyTo = nil
            },
            onSendAudio: { url in
                chatViewModel.uploadAndSendMediaMessage(fileURL: url, fileName: "audio.m4a", mimeType: "audio/m4a")
            },
            onImageButtonTap: {
                hideKeyboard()
                showMediaPickerOverlay = true
            },
            onCancelReply: { inReplyTo = nil }
        )
        .background(Design.Color.white.shadow(radius: 4))
        .padding(.bottom, 0)
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

    var body: some View {
        Button(action: { onHeaderTap() }) {
            ChatHeaderView(
                title: selectedRoom.name,
                subtitle: subtitleText(),
                image: avatarURL(),
                color: selectedRoom.randomeProfileColor
            ) {
                onDismiss()
            }
            .background(Design.Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    func subtitleText() -> String {
        if selectedRoom.isGroup {
            return "\(selectedRoom.participants.count) Members"
        } else {
            return selectedRoom.opponent?.isOnline ?? false ? "Online" : lastActiveString(from: selectedRoom.opponent?.lastSeen)
        }
    }
    
    func avatarURL() -> String? {
        return selectedRoom.avatarUrl
    }
}

// MARK: - Message Section Wrapper
struct MessagesSection: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let selectedRoom: RoomModel
    @Binding var selectedMessage: ChatMessageModel?
    @Binding var previousMessage: ChatMessageModel?
    @Binding var bubbleFrame: CGRect?
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    @Namespace var bottomID
    var nsPopover: Namespace.ID
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
    @State private var pendingAutoscroll = false
    @State private var didInitialScroll = false
    @State private var userIsDragging = false
    @State private var lastTopTrigger: CFAbsoluteTime = 0
    private let topTriggerCooldown: CFTimeInterval = 0.8
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    TopEdgeWatcher(threshold: 12) { isAtTop in
                        guard isAtTop,
                              userIsDragging,
                              chatViewModel.didLoadMessages,
                              didInitialScroll,
                              !chatViewModel.isPagingTop
                        else { return }

                        let now = CFAbsoluteTimeGetCurrent()
                        guard now - lastTopTrigger > topTriggerCooldown else { return }
                        lastTopTrigger = now
                        chatViewModel.loadOlderIfNeeded()
                    }
                    
                    if chatViewModel.isPagingTop {
                        ProgressView().padding(.vertical, 8)
                    }

                    ForEach(groupedMessages, id: \.date) { section in
                        Text(section.title)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                        
                        ForEach(section.messages.indices, id: \.self) { index in
                            let message = section.messages[index]
                            let previous = index > 0 ? section.messages[index - 1] : nil
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
                                            withAnimation {
                                                chatViewModel.showNotAMemberBar = true
                                            }
                                        } else {
                                            if (message.content != thisMessageWasDeleted) {
                                                hideKeyboard()
                                                selectedMessage = $0
                                                previousMessage = previous
                                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                                withAnimation(.easeInOut) {
                                                    proxy.scrollTo(message.eventId, anchor: .center)
                                                }
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
                                    isForwarding: isForwarding,
                                    onToggleChange: {
                                        chatViewModel.toggleMessageSelection()
                                    },
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
                                .background(isHighlighted ? AnyView(Design.Color.blueGradient.opacity(0.8)) : AnyView(Color.clear))
                                .animation(.easeInOut(duration: 0.3), value: highlightedEventID)
                            }
                            .padding(.bottom, 8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: chatViewModel.typingUsers)
                            .id(message.eventId)
                        }
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                        .onAppear {
                            showScrollToBottomButton = false
                        }
                        .onDisappear {
                            showScrollToBottomButton = true
                        }
                }
                .onReceive(chatViewModel.$sections) { _ in
                    if !didInitialScroll {
                        didInitialScroll = true
                        scrollToBottomEnsuringLayout(proxy)
                    }
//                    else if chatViewModel.isPagingTop {
//                        // pin back to the same first id when paging up
//                        var tx = Transaction(); tx.disablesAnimations = true
//                        withTransaction(tx) { proxy.scrollTo(eventId, anchor: .top) }
//                    }
                }
                .onReceive(chatViewModel.$messages.map { $0.last?.eventId }.removeDuplicates()) { _ in
                    if didInitialScroll && !showScrollToBottomButton {
                        scrollToBottomEnsuringLayout(proxy)
                    }
                }
                // when existing messages mutate height (image replaces placeholder), pin if at bottom
                .onReceive(chatViewModel.$messages) { _ in
                    if didInitialScroll && !showScrollToBottomButton {
                        scrollToBottomEnsuringLayout(proxy)
                    }
                }
                .onChange(of: chatViewModel.typingUsers) { newUsers in
                    guard !newUsers.isEmpty else {
                        // When indicator disappears, scroll to last message normally
                        withAnimation {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                        return
                    }
                }
                .onChange(of: searchString) { newValue in
                    updateSearchResults(for: newValue)
                }
                // Only show spacer if a message is selected
                if selectedMessage != nil {
                    Spacer()
                        .frame(height: 250)
                        .transition(.opacity) // optional: smooth fade
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkScrollToMessageProxy)) { note in
                if let messageId = note.userInfo?["messageId"] as? String {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(messageId, anchor: .center)
                    }
                    highlightMessage(messageId)
                }
            }
            .background(Design.Color.appGradient.opacity(0.2))
            .onAppear {
                scrollProxy = proxy
                addObserversIfNeeded()
                //scrollToBottom(proxy: proxy)
            }
            .onDisappear {
                removeObservers()
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            screenWidth = geo.size.width
                        }
                }
                    .frame(height: 0)
            )
            .overlay(
                Group {
                    if chatViewModel.showNotAMemberBar {
                        ZStack {
                            // Dimmed background
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                                .onTapGesture { } // disable taps on background

                            // Centered alert
                            VStack(spacing: 20) {
                                NotAMemberBar(
                                    title: "You can't react to messages,",
                                    description: "you are no longer a member."
                                )

                                Button(action: {
                                    withAnimation {
                                        chatViewModel.showNotAMemberBar = false
                                    }
                                }) {
                                    Text("Dismiss")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            )
        }
        .onPreferenceChange(MessageBubbleAnchorKey.self) { value in
            bubbleFrame = value
        }
        .coordinateSpace(name: "chatScroll")
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in userIsDragging = true }
                .onEnded { _ in
                    // settle a moment after finger lifts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        userIsDragging = false
                    }
                }
        )
    }
    
    // 1) Put this helper inside MessagesSection
    private func scrollToBottomEnsuringLayout(_ proxy: ScrollViewProxy) {
        let jump = {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
        // multiple passes to catch late layout (image decode, async heights)
        DispatchQueue.main.async {
            jump()
            DispatchQueue.main.async {
                jump()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { jump() }
            }
        }
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
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
    
    private func addObserversIfNeeded() {
        guard !didAddObservers else { return }

        prevObserver = NotificationCenter.default.addObserver(
            forName: .scrollToPreviousSearchResult,
            object: nil,
            queue: .main
        ) { _ in
            scrollToPreviousSearchResult()
        }

        nextObserver = NotificationCenter.default.addObserver(
            forName: .scrollToNextSearchResult,
            object: nil,
            queue: .main
        ) { _ in
            scrollToNextSearchResult()
        }
        
        bottomObserver = NotificationCenter.default.addObserver(
            forName: .scrollToBottom,
            object: nil,
            queue: .main
        ) { _ in
            if let scrollProxy = scrollProxy {
                scrollToBottom(proxy: scrollProxy)
            }
        }

        didAddObservers = true
    }

    private func removeObservers() {
        if let prevObserver = prevObserver {
            NotificationCenter.default.removeObserver(prevObserver)
            self.prevObserver = nil
        }

        if let nextObserver = nextObserver {
            NotificationCenter.default.removeObserver(nextObserver)
            self.nextObserver = nil
        }

        if let bottomObserver = bottomObserver {
            NotificationCenter.default.removeObserver(bottomObserver)
            self.bottomObserver = nil
        }

        didAddObservers = false
    }

    
    private func updateSearchResults(for text: String) {
        guard !text.isEmpty else {
            searchResultEventIDs = []
            currentSearchIndex = 0
            resultCount = 0
            highlightedEventID = nil
            showNoResultsAlert = false
            return
        }

        // Filter matching messages
        let filtered = chatViewModel.messages.filter { $0.isSelectedFromSearch(searchString: text) }
        searchResultEventIDs = filtered.map { $0.eventId }
        currentSearchIndex = 0
        resultCount = searchResultEventIDs.count
        highlightedEventID = searchResultEventIDs.first
        
        if resultCount <= 0 {
            showNoResultsAlert = true
        } else {
            showNoResultsAlert = false
        }
        // Scroll to first match
        if let firstID = searchResultEventIDs.first {
            scrollToMessage(eventID: firstID)
        }
    }

    private func scrollToPreviousSearchResult() {
        guard !searchResultEventIDs.isEmpty else { return }
        currentSearchIndex = max(currentSearchIndex - 1, 0)
        highlightedEventID = searchResultEventIDs[currentSearchIndex]
        scrollToMessage(eventID: searchResultEventIDs[currentSearchIndex])
    }

    private func scrollToNextSearchResult() {
        guard !searchResultEventIDs.isEmpty else { return }
        currentSearchIndex = min(currentSearchIndex + 1, searchResultEventIDs.count - 1)
        highlightedEventID = searchResultEventIDs[currentSearchIndex]
        scrollToMessage(eventID: searchResultEventIDs[currentSearchIndex])
    }
    
    func shouldShowSenderInfo(current: ChatMessageModel, previous: ChatMessageModel?) -> Bool {
        guard let previous = previous else { return true } // Always show for first message
        return previous.sender != current.sender
    }
    
    // MARK: - Group Messages by Day
    var groupedMessages: [MessageSection] {
        func startOfDay(_ d: Date) -> Date {
            Calendar.current.startOfDay(for: d)
        }
        
        let dict = Dictionary(grouping: chatViewModel.messages) { msg in
            startOfDay(Date(timeIntervalSince1970: TimeInterval(msg.timestamp) / 1000))
        }
        
        return dict.keys.sorted().map { day in
            MessageSection(
                date: day,
                title: headerTitle(for: day),
                messages: dict[day]!.sorted(by: { $0.timestamp < $1.timestamp })
            )
        }
    }
    
    func headerTitle(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: day)
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
        isForwarding: Bool = false,
        onToggleChange: (@escaping () -> Void),
        onURLTapped: ((String) -> Void)? = nil
    ) -> some View {
        if message.isReceived {
            let senderModel = members.first { $0.userId == message.sender }
            let senderName = senderModel?.fullName ?? senderModel?.phoneNumber
            let senderAvatarURL = senderModel?.avatarURL ?? senderModel?.imageURL
            let showSenderInfo = isGroupChat && (previousMessage?.sender != message.sender)
            
            ReceiverMessageView(
                message: message,
                isGroupChat: isGroupChat,
                senderName: senderName ?? "",
                senderAvatarURL: senderAvatarURL,
                showSenderInfo: showSenderInfo,
                onAvatarTap: {
                    // Show user profile
                },
                onDownloadNeeded: onDownloadNeeded,
                onTap: {},
                onLongPress: { onLongPress(message) },
                onMessageRead: { onMessageRead(message) },
                onScrollToMessage: { eventId in
                    onScrollToMessage?(eventId)
                },
                onURLTapped: onURLTapped, onToggleChange: {
                    onToggleChange()
                },
                selectedEventId: selectedMessage?.eventId,
                searchText: searchString,
                isForwarding: isForwarding
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, screenWidth * 0.30)
            
        } else {
            let senderModel = members.first { $0.userId == message.sender }
            let senderName = senderModel?.fullName ?? senderModel?.phoneNumber
            
            SenderMessageView(
                message: message,
                senderName: senderName ?? "",
                onDownloadNeeded: onDownloadNeeded,
                onTap: {},
                onLongPress: { onLongPress(message) },
                onScrollToMessage: { eventId in
                    onScrollToMessage?(eventId)
                },
                selectedEventId: selectedMessage?.eventId,
                searchText: searchString,
                isForwarding: isForwarding,
                onToggleChange: {
                    onToggleChange()
                },
                senderImage: loadProfileImage(),
                onURLTapped: onURLTapped
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 20)
        }
    }
    
    private func loadProfileImage() -> String {
        if let profile = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let imageUrlString = profile.profileImageUrl {
            return imageUrlString
        }
        return ""
    }
}

struct NotAMemberBar: View {
    // MARK: - Properties
    let title: String
    let description: String

    var body: some View {
        VStack {
            VStack {
                Text(title)
                Text(description)
            }
            .multilineTextAlignment(.center)
            .font(Design.Font.regular(14))
            .foregroundColor(Design.Color.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .padding(.horizontal, 60)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Message?")
                .font(.headline)
                .padding([.top, .leading], 20)

            VStack {
                
                if isSender {
                    actionButton(label: "Delete for everyone") {
                        onDeleteForEveryone()
                    }
                }

                actionButton(label: "Delete for me") {
                    onDeleteForMe()
                }

                actionButton(label: "Cancel") {
                    onCancel()
                }
            }.padding([.bottom], 14)
        }
        .background(Color.white)
        .cornerRadius(16)
        .padding(40)
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
                    .font(Design.Font.regular(14))
                    .padding(.trailing, 20)
                    .padding(.vertical, 6)
            }
            .foregroundColor(Design.Color.primaryText.opacity(0.6))
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
        HStack(spacing: 8) {
            Image("TFsearch")
                .resizable()
                .frame(width: 20, height: 20)
                .padding(.leading, 8)
            TextField("Search", text: $searchText, onCommit: {
                // This runs when the keyboard Search/Return button is tapped
                hideKeyboard()
                   if resultCount == 0 {
                       withAnimation {
                           showNoResultsAlert = true
                       }
                   } else {
                       withAnimation {
                           showNoResultsAlert = false
                       }
                   }
            })
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.black)
                .background(Color.clear)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if !searchText.isEmpty {
                SearchResultCountView(resultCount: $resultCount,
                                      onPrevious: onPrevious,
                                      onNext: onNext, showNoResultsAlert: $showNoResultsAlert)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: 40)
    }
}

struct SearchResultCountView: View {
    @Binding var resultCount: Int
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    @Binding var showNoResultsAlert: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                onPrevious?()
            }) {
                Image(systemName: "chevron.up")
                    .foregroundColor(.black)
                    .imageScale(.medium)
                    .frame(width: 16, height: 16)
            }
            .disabled(showNoResultsAlert)
            .opacity(showNoResultsAlert ? 0.5 : 1.0)
            
            Text("\(resultCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
            Button(action: {
                onNext?()
            }) {
                Image(systemName: "chevron.down")
                    .foregroundColor(.black)
                    .imageScale(.medium)
                    .frame(width: 16, height: 16)
            }
            .disabled(showNoResultsAlert)
            .opacity(showNoResultsAlert ? 0.5 : 1.0)
        }
        .frame(width: 80, height: 26)
        .background(Color(uiColor: #colorLiteral(red: 0.8156862745, green: 0.8470588235, blue: 0.9294117647, alpha: 1)))
        .cornerRadius(10)
    }
}

struct UnlockUserButton: View {
    var opponentUserId: String  // The user ID of the opponent
    var action: () -> Void

    var body: some View {
        VStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            }) {
                HStack(spacing: 12) {
                    // Image for "Unblock"
                    Image("shield-cross-blue")  // Assuming this is your custom image asset
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    // Text for the button
                    Text("Unblock User")
                        .font(Design.Font.bold(16))
                }
                // Center the content inside the button
                .padding(.top, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)  // Make the HStack take full width
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
            // Transparent background, tap to dismiss
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            // Bottom full-width panel
            VStack(spacing: 0) {
                Spacer() // Pushes the content to bottom
                
                VStack {
                    HStack(spacing: 32) {
                        MediaPickerButton(icon: "camera", title: "Camera") {
                            onItemSelected(.camera)
                        }
                        MediaPickerButton(icon: "gallery", title: "Gallery") {
                            onItemSelected(.gallery)
                        }
                        MediaPickerButton(icon: "document", title: "Document") {
                            onItemSelected(.document)
                        }
                        MediaPickerButton(icon: "music", title: "Audio") {
                            onItemSelected(.audio)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(CustomRoundedCornersShape(radius: 24, roundedCorners: [.topRight, .topLeft]))
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
        VStack(spacing: 6) {
            Button(action: action) {
                Circle()
                    .fill(Design.Color.appGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(icon)
                            .font(.system(size: 24))
                    )
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

enum MediaPickerType {
    case camera, gallery, document, audio
}

// MARK: - URL Wrapper for WebViewScreen
private struct URLWrapper: Identifiable {
    let id = UUID()
    let urlString: String
}
