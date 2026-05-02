//
//  ChatTabView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import Combine

enum NavigationTarget: Hashable {
    case chat(room: RoomModel, isSearching: Bool = false)
    case groupDetails(room: RoomModel, currentUser: ContactModel?, sharedMedia: [ChatMessageModel]?)
    case userDetails(room: RoomModel, user: ContactModel?, sharedMedia: [ChatMessageModel]?)
    case callManager(room: RoomModel, autoAccept: Bool)
    case messageInfo(room: RoomModel, user: ContactModel?, selectedMessage: ChatMessageModel)
    case notificationSettings(room: RoomModel)
    case lockedRoom(rooms: [RoomModel])
    case manageLockedChats
}
struct RoomListView: View {
    @State private var showContactsList = false
    @State private var showInviteView = false  // Add this

    @StateObject private var viewModel: RoomListViewModel
    @EnvironmentObject var router: Router
    @ObservedObject private var chatViewModel: ChatViewModel

    private var chatRepository: ChatRepository
    @Binding var navPath: NavigationPath
    @State private var didRunInitialLoad = false

    @State private var selectedRoomForMenu: RoomModel? = nil
    @State private var rowFrame: CGRect? = nil
    
    @State private var showMoreMenu = false

    @State private var showDelete = false
    @State private var showMute = false
    @State private var showBlock = false
    @State private var showUnBlock = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showLockChat = false
    @State private var showSecureChat = false
    @State private var showChatProtected = false
    @State private var showSetPinView = false
    @State private var isConfirmMode = true
    @State private var showMismatchAlert = false
    @EnvironmentObject var callManager: CallManager

    @State private var scrollOffset: CGFloat = 0
    @State private var showLockedButton: Bool = false
    struct ScrollOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    @State private var selectedSecurityOption: LockSecurityOption? = {
        if let raw: String = Storage.get(for: .lockSecurityOption, type: .userDefaults, as: String.self) {
            return LockSecurityOption(rawValue: raw)
        }
        return .biometric
    }()

    init(navPath: Binding<NavigationPath>) {
        self._navPath = navPath
        let viewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = ObservedObject(wrappedValue: vm)
        
        self.chatRepository = DIContainer.shared.container.resolve(ChatRepository.self)!
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Design.Color.backgroundColor.ignoresSafeArea()
                ZStack(alignment: .top) {
                    if (CallManager.shared.callState == .ongoing || CallManager.shared.callState == .outgoing || CallManager.shared.callState == .incoming) && CallManager.shared.currentRoomModel != nil {                        OngoingCallWidget(
                            participants: CallManager.shared.currentRoomModel!.participants,
                            callType: CallManager.shared.isVideoCall ? Constants.video.localized.lowercased() : Constants.voice.localized,
                            callState: CallManager.shared.callState,
                            onJoinCall: {
                                if(CallManager.shared.currentRoomModel != nil){
                                    CallManager.shared.presentCall(for: CallManager.shared.currentRoomModel!)
                                    CallManager.shared.callState = .ongoing
                                }
                            }
                        )
                        .padding(.horizontal, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1) // ensure it appears above messages
                    }
                }
                .background(Design.Color.appGradient.opacity(0.2))

                if viewModel.filteredRooms.isEmpty && !viewModel.didLoadRooms {
                    VStack(){
                        tabFilters
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        //searchBar
                        //if !viewModel.filteredRooms.isEmpty && viewModel.didLoadRooms {
                                                    tabFilters
                        //}
                        let isLockedChatsEnabled: Bool = Storage.get(for: .isLockedChatsEnabled, type: .userDefaults, as: Bool.self) ?? true
                        if isLockedChatsEnabled && showLockedButton {
                            if viewModel.getLockedRooms().count > 0 {
                                LockedChatsButton(action: {
                                    
                                    selectedSecurityOption = {
                                        if let raw: String = Storage.get(for: .lockSecurityOption, type: .userDefaults, as: String.self) {
                                            return LockSecurityOption(rawValue: raw)
                                        }
                                        return .biometric
                                    }()
                                    
                                    if selectedSecurityOption == .pin {
                                        isConfirmMode = true
                                        DispatchQueue.main.asyncAfter(deadline: .now()){
                                            showSetPinView = true
                                        }
                                    } else {
                                        Task {
                                            let result = await BiometricAuthService.shared.authenticate(
                                                reason: Constants.authTxt.rawValue
                                            )
                                            switch result {
                                            case .success(let success) where success:
                                                navPath.append(NavigationTarget.lockedRoom(rooms: viewModel.getLockedRooms()))
                                            case .failure, .success:
                                                // Authentication failed or cancelled
                                                print("")
                                            }
                                        }
                                    }
                                }).transition(.move(edge: .top).combined(with: .opacity))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLockedButton)
                            }
                        }
                        if viewModel.isDownloadingMessages {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: UIConstants.Symbols.arrowDownCircleFilled)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text(Constants.downloadingMessages.localized)
                                        .font(.system(size: 13, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    // optional: show % if you want
                                    Text("\(Int(viewModel.messageDownloadProgress * 100))%")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                                
                                // progress "track"
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 5)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: max(8, CGFloat(viewModel.messageDownloadProgress) * UIScreen.main.bounds.width * 0.7),
                                               height: 5)
                                        .animation(.easeOut(duration: 0.25), value: viewModel.messageDownloadProgress)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                            )
                            //.padding(.horizontal, 12)
                            .padding(.top, 4)
                        }
                        roomList
                    }
                    .background(Design.Color.backgroundColor)
                    if !viewModel.filteredRooms.isEmpty && viewModel.didLoadRooms || showInviteView{
                        
                        floatingButton
                            .position(
                                x: geometry.size.width - 20 - 22,
                                y: geometry.size.height - 25 - 22
                            )
                    }
                }
                if viewModel.isHydrating {
                    RestoreChatsAnimationView(
                        progress: viewModel.hydrationProgress,
                        hydratedRooms: viewModel.hydrationHydrated,
                        totalRooms: viewModel.hydrationTotal
                    )
                    .background(.ultraThinMaterial)   // slight blur
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .onAppear {
                chatViewModel.leaveCurrentRoom()
                guard !didRunInitialLoad else { return }
                didRunInitialLoad = true
                restoreSession()
                viewModel.loadRooms()
                setupNotificationListener()
                DeepLinkManager.shared.pendingURL = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToChat)) { notification in
                handleNavigateToChat(notification)
            }
            .sheet(isPresented: $showContactsList, onDismiss: {
                viewModel.participants.removeAll()
                viewModel.invitedContacts.removeAll()
            }) {
                SelectContactsListView(
                    participants: $viewModel.participants.asLite(),
                    invitedContacts: $viewModel.invitedContacts.asLite()
                ) { roomName, displayImage in
                    if let currentUserId = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)?.userId {
                        let userIds = viewModel.participants.compactMap { $0.userId }
                        if !userIds.isEmpty {
                            if userIds.count == 1 {
                                viewModel.startChat(with: userIds[0], currentUserId: currentUserId) { roomModel in
                                    viewModel.selectedRoom = roomModel
                                    viewModel.participants.removeAll()
                                    if let roomModel = roomModel {
                                        $navPath.wrappedValue.append(NavigationTarget.chat(room: roomModel))
                                    }
                                }
                            } else {
                                viewModel.createRoom(currentUser: currentUserId, users: userIds, roomName: roomName, roomDisplayImageUrl: displayImage, completion: { roomModel in
                                    viewModel.selectedRoom = roomModel
                                    viewModel.participants.removeAll()
                                    if let roomModel = roomModel {
                                        // set group image
                                        $navPath.wrappedValue.append(NavigationTarget.chat(room: roomModel))
                                    }
                                })
                            }
                        }
                    }
                    showContactsList.toggle()
                } onDismiss: {
                    showContactsList.toggle()
                    viewModel.participants.removeAll()
                    viewModel.invitedContacts.removeAll()
                }
            }
            .hideKeyboardOnTap()
            .sheet(isPresented: $showSetPinView) {
                SetPinView(onSave: { pin in
                    if isConfirmMode {
                       let savedPIN = Storage.get(for: .lockPin, type: .userDefaults, as: String.self)
                        if savedPIN == pin {
                            navPath.append(NavigationTarget.lockedRoom(rooms: viewModel.getLockedRooms()))
                        } else {
                            showMismatchAlert = true
                        }
                    } else {
                        Storage.save(pin, for: .lockPin, type: .userDefaults)
                        showSetPinView = false
                        if let room = selectedRoomForMenu {
                            viewModel.toggeleLocked(for: room)
                            viewModel.lockedRooms.append(room)
                            viewModel.filteredRooms.removeAll(where: { $0.id == room.id })
                        }
                        showSecureChat = false
                        showChatProtected = true
                    }
                }, isConfirmMode: isConfirmMode)
            }
            .alert(Constants.incorrectPin.localized, isPresented: $showMismatchAlert) {
                Button(Constants.ok.localized, role: .cancel) { }
            }
            .overlay {
                if showDelete {
                    DeleteChatView(
                        onDelete: {
                            if let room = selectedRoomForMenu {
                                viewModel.clearChatAndDeleteRoomLocally(roomId: room.id)
                                viewModel.toggeleDeleted(for: room)
                                print("Deleted")
                                showDelete = false
                            }
                        },
                        onCancel: { showDelete = false },
                        isGroup: selectedRoomForMenu?.isGroup ?? false
                    )
                }
                
                if showLockChat {
                    LockChatConfirmationView {
                        showSecureChat = true
                        showLockChat = false
                    } onCancel: {
                        showLockChat = false
                    }
                }
                
                if showSecureChat {
                    SecureYourChatsView {
                        Task {
                            let result = await BiometricAuthService.shared.authenticate(
                                reason: Constants.authTxt.rawValue
                            )
                            
                            switch result {
                            case .success(let success) where success:
                                if let room = selectedRoomForMenu {
                                    viewModel.toggeleLocked(for: room)
                                    viewModel.lockedRooms.append(room)
                                    viewModel.filteredRooms.removeAll { $0.id == room.id }
                                }
                                showSecureChat = false
                                showChatProtected = true
                                
                            case .failure, .success:
                                // Authentication failed or cancelled
                                showSecureChat = false
                            }
                        }
                    }
                    onSetPIN: {
                        isConfirmMode = false
                        showSetPinView = true
                    } onCancel: {
                        showSecureChat = false
                    }
                }
                
                if showChatProtected {
                    ChatsProtectedView {
                        showChatProtected = false
                    } onCancel: {
                        showChatProtected = false
                    }
                }
                
                if showMute {
                    MuteView(
                        onConfirm: { duration in
                            if let room = selectedRoomForMenu {
                                viewModel.muteRoomNotifications(for: room, duration: duration) { _ in
                                    if !room.isMuted {
                                        viewModel.toggeleMuted(for: room)
                                        room.isMuted = true
                                    }
                                }
                                print("Muted for \(duration.label)")
                                showMute = false
                            }
                        },
                        onCancel: { showMute = false }
                    )
                }

                if showBlock {
                    BlockConfirmationView(
                        userName: selectedRoomForMenu?.name ?? "",
                        onBlock: {
                            showBlock = false
                            guard let room = selectedRoomForMenu,
                                  let user = room.opponent
                            else { return }
                            
                            viewModel.banUser(from: room, user: user, reason: Constants.blockedByAdmin.localized) { success in
                                if success {
                                    if selectedRoomForMenu?.isBlocked == false {
                                        viewModel.toggeleBlocked(for: room)
                                    }
                                    selectedRoomForMenu?.isBlocked = true
                                    print("User banned successfully")
                                }
                            }
                        },
                        onCancel: { showBlock = false }
                    )
                }
                
                if showUnBlock {
                    UnblockConfirmationView(
                        userName: selectedRoomForMenu?.name ?? "",
                        onUnblock: {
                            showUnBlock = false
                            guard let room = selectedRoomForMenu,
                                  let user = room.opponent
                            else { return }
                            
                            viewModel.unbanUser(from: room, user: user) { success in
                                if success {
                                    if selectedRoomForMenu?.isBlocked == true {
                                        viewModel.toggeleBlocked(for: room)
                                    }
                                    selectedRoomForMenu?.isBlocked = false
                                    print("User unbanned successfully")
                                }
                            }
                        },
                        onCancel: { showUnBlock = false }
                    )
                }
            }
            
            if showMoreMenu {
                if let room = selectedRoomForMenu, let frame = rowFrame {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .zIndex(100)
                        .onTapGesture {
                            selectedRoomForMenu = nil
                            rowFrame = nil
                        }
                    
                    MoreMenuView(
                        roomModel: room,
                        onMarkAsRead: {
                            viewModel.toggeleRead(for: room)
                            room.isRead = true
                        },
                        onMarkAsUnread: {
                            viewModel.toggeleRead(for: room)
                            room.isRead = false
                        },
                        onMute: {
                            showMute = true
                        },
                        onUnmute: {
                            viewModel.unmuteRoomNotifications(for: room) { _ in
                                if room.isMuted {
                                    viewModel.toggeleMuted(for: room)
                                    room.isMuted = false
                                }
                            }
                        },
                        onAddToFavorites: {
                            viewModel.toggeleFavorite(for: room)
                            room.isFavorite = true
                        },
                        onRemoveFromFavorites: {
                            viewModel.toggeleFavorite(for: room)
                            room.isFavorite = false
                        },
                        onBlock: {
                            showBlock = true
                        },
                        onUnblock: {
                            showUnBlock = true
                        },
                        onDeleteChat: {
                            showDelete = true
                        }, onLockChat: {
                            showLockChat = true
                        },
                        onDismiss: { showMoreMenu = false }
                    )
                    .frame(width: UIScreen.main.bounds.width)
                    .position(
                        x: frame.midX,
                        y: (frame.maxY < 400) ? frame.maxY : 467 // menu appears just below button
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(200)
                }
            }
        }
        .navigationDestination(for: NavigationTarget.self) { target in
            switch target {
            case .chat(room: let room, let isSearching):
                ChatView(
                    selectedRoom: room,
                    navPath: $navPath,
                    isSearching: isSearching,
                    onDismiss: {
                        if !room.isRead {
                            viewModel.toggeleRead(for: room)
                        }
                        room.isRead = true
                        viewModel.selectedRoom = nil
                    },
                    onReturnFromProfile: {
                        // Callback to trigger search when returning from UserProfileView
                        if let chatView = ChatView(
                            selectedRoom: room,
                            navPath: $navPath,
                            isSearching: true,
                            onDismiss: { viewModel.selectedRoom = nil },
                            onReturnFromProfile: nil
                        ) as? ChatView {
                            chatView.isSearching = true
                        }
                    }
                )
                .navigationBarBackButtonHidden(true)
                .navigationBarHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                
            case .groupDetails(let roomModel, let currentUser, let sharedMedia):
                let chatViewModel = DIContainer.shared.container.resolve(ChatViewModel.self)!
                GroupDetailsView(
                    roomModel: roomModel,
                    currentUser: currentUser,
                    sharedMediaPayload: sharedMedia,
                    roomListViewModel: self.viewModel,
                    navPath: $navPath,
                    onDeleteGroup: {
                        viewModel.selectedRoom = nil
                        if !navPath.isEmpty {
                            navPath.removeLast(2)
                        }
                    },
                    onClearChat: {
                        viewModel.clearChat(roomId: roomModel.id)
                    }
                )
                .navigationBarBackButtonHidden(true)
                .navigationBarHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            case .userDetails(room: let room, user: let user, let sharedMedia):
                if let currentUser = user {
                    UserProfileView(user: currentUser, room: room, sharedMediaPayload: sharedMedia, navPath: $navPath) {
                        if !navPath.isEmpty {
                            navPath.removeLast()
                        }
                    } onBlock: {
                        if let opponent = room.opponent {
                            viewModel.banUser(from: room, user: opponent) { success in
                                if success {
                                    viewModel.toggeleBlocked(for: room)
                                    if selectedRoomForMenu?.id == room.id {
                                        selectedRoomForMenu?.isBlocked = true
                                    }
                                    room.isBlocked = true
                                    print("User banned successfully")
                                }
                            }
                        }
                    } onUnBlock: {
                        if let opponent = room.opponent {
                            viewModel.unbanUser(from: room, user: opponent)
                            viewModel.toggeleBlocked(for: room)
                        }
                    }
                    onDeleteChat: {
                        viewModel.clearChatAndDeleteRoomLocally(roomId: room.id)
                        viewModel.toggeleDeleted(for: room)
                        print("Deleted")
                        showDelete = false
                    } onClearChat: {
                        viewModel.clearChat(roomId: room.id)
                    }
                    .navigationBarBackButtonHidden(true)
                    .navigationBarHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                }
            case .callManager(room: let room, autoAccept: let autoAccept):
                    CallScreen(roomModel: room, callState: .outgoing)
                        .environmentObject(CallManager.shared)
                    
            case .messageInfo(room: let room, user: let user, let selectedMessage):
                if let currentUser = user {
                    if room.isGroup {
                        GroupMessageInfoView(message: selectedMessage, user: currentUser, currentRoom: room, navPath: $navPath)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        
                    } else {
                        SingleMessageInfoView(message: selectedMessage, user: currentUser, currentRoom: room, navPath: $navPath)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        
                    }
                    
                }
            case .notificationSettings(room: let room):
                NotificationSettingsView(room: room, onBack: {
                    if !navPath.isEmpty {
                        navPath.removeLast()
                    }
                },navPath: $navPath)
            case .lockedRoom(rooms: _):
                LockedChatView(rooms: $viewModel.lockedRooms, navPath: $navPath)
            case .manageLockedChats:
                ManageLockedChatsView(navPath: $navPath)
            }
        }
        .refreshable {
            ContactManager.shared.syncContacts()
            Storage.save(false, for: .roomsLoadedFromNetwork, type: .userDefaults)
        }.onReceive(
            NotificationCenter.default.publisher(for: .deepLinkOpenChatDetail)
        ) { note in

            guard let type = note.userInfo?["type"] as? String else { return }

            switch type {

            // ----------------------------------------------------------
            // OPEN CONVERSATION
            // ----------------------------------------------------------
            case DeepLinkType.conversation.rawValue:
                guard let roomId = note.userInfo?["roomId"] as? String else { return }

                if let room = getRoom(by: roomId) {
                    viewModel.selectedRoom = room
                    navPath.append(NavigationTarget.chat(room: room))
                } else {
                    print("Room not found:", roomId)
                }

            // ----------------------------------------------------------
            // OPEN USER PROFILE INSIDE CONVERSATION
            // ----------------------------------------------------------
            case DeepLinkType.userProfile.rawValue:
                guard
                    let roomId = note.userInfo?["roomId"] as? String,
                    let userId = note.userInfo?["userId"] as? String
                else { return }

                if let room = getRoom(by: roomId) {
                    viewModel.selectedRoom = room
                    navPath.append(NavigationTarget.chat(room: room))

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NotificationCenter.default.post(
                            name: .deepLinkOpenProfile,
                            object: nil,
                            userInfo: ["userId": userId]
                        )
                    }

                } else {
                    print("Room not found:", roomId)
                }

            // ----------------------------------------------------------
            // OPEN MESSAGE INSIDE CONVERSATION
            // ----------------------------------------------------------
            case DeepLinkType.message.rawValue:
                guard
                    let roomId = note.userInfo?["roomId"] as? String,
                    let messageId = note.userInfo?["messageId"] as? String
                else { return }

                print("Deep link → open message:", messageId)

                if let room = getRoom(by: roomId) {
                    viewModel.selectedRoom = room
                    navPath.append(NavigationTarget.chat(room: room))

                    // Delay to ensure chat view is visible
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NotificationCenter.default.post(
                            name: .deepLinkScrollToMessage,
                            object: nil,
                            userInfo: ["messageId": messageId]
                        )
                    }

                } else {
                    print("Room not found:", roomId)
                }

            default:
                print("Unknown deep link type:", type)
            }
        }

    }
    
    private func getRoom(by roomId: String) -> RoomModel? {
        // First, try to find in the loaded filtered rooms
        if let room = viewModel.filteredRooms.first(where: { $0.id == roomId }) {
            return room
        }
        
        // If not found, try fetching from repository
        if let room = chatRepository.getExistingRoomModel(roomId: roomId) {
            return room
        }
        
        // Room not found
        return nil
    }
    // MARK: - Empty State View (Extracted)
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 150)
            
            // Dog image from assets
            Image(UIConstants.Symbols.animal_ss)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding(.bottom, 10)
            
            // Empty state text
            VStack(spacing: 0) {
                Text(Constants.inboxEmpty.localized)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                Text(Constants.startNewChat.localized)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
            
            // Buttons
            VStack(spacing: 20) {
                Button(action: {
                    // showContactsList = true
                    showInviteView = true
                }) {
                    Text(Constants.messageContact.localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.4, green: 0.5, blue: 1.0),
                                    Color(red: 0.7, green: 0.3, blue: 0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                Button(action: {
                    showInviteView = true
                }) {
                    Text(Constants.inviteFriend.localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Design.Color.backgroundColor)
    }
   

    // MARK: - Updated Invite Contacts View - COMPACT 224pt Design

    private var inviteContactsView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Discover Contacts Card - Compact 224pt design
                    VStack(spacing: 0) {
                        Text(Constants.discoverContactsYal.localized)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        // Contact Avatars Row - no scroll, all visible
                        HStack(spacing: 12) {
                            // Rishabh
                            VStack(spacing: 8) {
                                Image("mask_group_m")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text("Rishabh")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Sam K
                            VStack(spacing: 8) {
                                Image("mask_group")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text("Sam K")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Khushbu
                            VStack(spacing: 8) {
                                Image("mask_group_g")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text("Khushbu")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Jordan
                            VStack(spacing: 8) {
                                Image("ss_boy")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text("Jordan")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Priya S
                            VStack(spacing: 8) {
                                Image("white_girl")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text("Priya S")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Choose Contact Button
                        Button(action: {
                            showContactsList = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showInviteView = false
                            }
                        }) {
                            Text(Constants.chooseContact.localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.38, green: 0.51, blue: 1.0),
                                            Color(red: 0.64, green: 0.36, blue: 0.95)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    }
                    .frame(height: 224)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 32/255,green: 45/255,blue: 53/255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.top, 10)
                    
                    // Invite Friends Section
                    Button(action: {
                        shareInviteLink()
                    }) {
                        HStack(spacing: 16) {
                            // Icon with objects.png
                            Image(UIConstants.Symbols.objects)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(Constants.inviteFriends.localized)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(Constants.connectFriendsYal.localized)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Image(systemName: UIConstants.Symbols.chevronRight)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer(minLength: 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Design.Color.backgroundColor)
    }

    // MARK: - Helper function to share invite link
    private func shareInviteLink() {
        let inviteText = Constants.inviteShareText.localized
        let activityController = UIActivityViewController(
            activityItems: [inviteText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
}

struct LockedChatsButton: View {
    var action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(UIConstants.Symbols.lockWhite)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Design.Color.appGradient)
                .clipShape(Circle())
            
            // Text
            Text(Constants.lockedChats.localized)
                .font(Design.Font.bold(14))
                .foregroundColor(Design.Color.primaryTextColor)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Design.Color.backgroundColor)
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Private Views
private extension RoomListView {

    var searchBar: some View {
        SearchBarView(placeholder: Constants.searchPlaceholderText.localized,
                      text: $viewModel.searchText)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
    }

    var tabFilters: some View {
        TabFiltersView(filters: ChatFilter.allCases, selectedFilter: $viewModel.selectedFilter)
    }

    var roomList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                let isLockedChatsEnabled: Bool =
                Storage.get(for: .isLockedChatsEnabled, type: .userDefaults, as: Bool.self) ?? true
                // Apply filter conditionally
                let rooms: [RoomModel] = {
                    if isLockedChatsEnabled {
                        return viewModel.filteredRooms.filter { !$0.isLocked && !$0.isDeleted}
                    } else {
                        return viewModel.filteredRooms.filter {!$0.isDeleted}
                    }
                }()
                if rooms.isEmpty {
                    if showInviteView {
                        inviteContactsView
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(1)
                    } else if viewModel.didLoadRooms {
                        emptyStateView
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .zIndex(0)
                    }
                } else {
                    ForEach(rooms) { room in
                        roomButton(for: room)
                    }
                }
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                }
                .frame(height: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .coordinateSpace(name: "scroll")
        .frame(maxWidth: .infinity)
        .background(Design.Color.backgroundColor)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            
            let scrollTop = Double(viewModel.filteredRooms.count) * 58.6
    
            if offset > (scrollTop + 40) {
                showLockedButton = true
            } else if offset < (scrollTop - 1) {
                showLockedButton = false
            }
        }
    }

    func roomButton(for room: RoomModel) -> some View {
        GeometryReader { geo in
            ConversationView(roomModel: room, typingIndicator: viewModel.typingIndicators[room.id] ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedRoom = room
                   // navPath.append(NavigationTarget.chat(room: room))
                    
                    if !navPath.isEmpty {
                        navPath.removeLast(navPath.count)
                    }
                    
                    DispatchQueue.main.async {
                        navPath.append(NavigationTarget.chat(room: room))
                    }
                }
                .onLongPressGesture {
                    self.viewModel.refreshRoom(for: room)
                    selectedRoomForMenu = room
                    // Store the button's frame in global coordinates
                    rowFrame = geo.frame(in: .global)
                    showMoreMenu = true
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
        }
        .frame(height: 48)
        .opacity(room.isBlocked ? 0.5 : 1.0)
    }

    func restoreSession() {
        if let session = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            viewModel.restoreSession(accessToken: session.matrixToken)
        }
    }
    
    func handleNavigateToChat(_ notification: Notification) {
        guard let data = notification.object as? [String: Any],
              let roomId = data["roomId"] as? String else {
            print("Invalid navigation data for chat")
            return
        }
        
        let autoAccept = data["autoAccept"] as? Bool ?? false
        
        // Find the room model with the matching ID
        if let room = viewModel.filteredRooms.first(where: { $0.id == roomId }) {
            print("Navigating to room: \(room.name), autoAccept: \(autoAccept)")
            viewModel.selectedRoom = room
            
            if autoAccept {
                // Navigate directly to CallManagerView with auto-accept
                let eventId = UUID().uuidString
                CallManager.shared.presentCall(for: room)
                navPath.append(NavigationTarget.callManager(room: room, autoAccept: true))
            } else {
                navPath.append(NavigationTarget.chat(room: room))
            }
        } else {
            print("Room not found with ID: \(roomId)")
        }
    }

    var floatingButton: some View {
        Button(action: {
            showContactsList.toggle()
        }) {
            ZStack {
                CustomRoundedCornersShape(radius: 12, roundedCorners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Design.Color.appGradient)
                    .frame(width: 44, height: 44)

                Image(UIConstants.Symbols.addWhite)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        }
        .shadow(radius: 10)
    }
    
    // MARK: - Notification Listener
    
    func setupNotificationListener() {
        // Subscribe to future notification events
        router.notificationNavigationSubject
            .sink { [self] event in
                handleNotificationNavigation(event: event)
            }
            .store(in: &cancellables)
        
        // Check if there's a pending navigation from before we were loaded
        if let pendingEvent = router.pendingNotificationNavigation {
            router.pendingNotificationNavigation = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.handleNotificationNavigation(event: pendingEvent)
            }
        }
    }
    
    func handleNotificationNavigation(event: NotificationNavigationEvent) {
        switch event {
        case .chat(let roomId, let eventId):
            navigateToChatFromNotification(roomId: roomId, eventId: eventId)
        }
    }
    
    func navigateToChatFromNotification(roomId: String, eventId: String?) {
        // Clear any existing navigation stack
        if !navPath.isEmpty {
            navPath.removeLast(navPath.count)
        }
        
        // Find room in existing rooms
        if let room = viewModel.filteredRooms.first(where: { $0.id == roomId }) {
            DispatchQueue.main.async {
                self.navPath.append(NavigationTarget.chat(room: room))
            }
        } else if let roomSummaryModel = chatRepository.getExistingRoomSummaryModel(roomId: roomId) {
            let roomModel = roomSummaryModel.materializeRoomModel()
            DispatchQueue.main.async {
                self.navPath.append(NavigationTarget.chat(room: roomModel))
            }
        }
    }
}
