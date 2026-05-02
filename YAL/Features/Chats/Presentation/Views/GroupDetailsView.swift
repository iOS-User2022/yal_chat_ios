//
//  GroupDetailsView.swift
//  YAL
//
//  Created by Vishal Bhadade on 27/05/25.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct GroupDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var safeAreaInsets: EdgeInsets = .init()
    @StateObject private var roomDetailsViewModel: RoomDetailsViewModel
    @ObservedObject private var roomListViewModel: RoomListViewModel
    @StateObject private var selectContactListViewModel: SelectContactListViewModel
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    @State private var isImagePickerPresented = false
    @StateObject private var chatViewModel: ChatViewModel
    @State private var showFullScreen = false
    @State var sharedMedia: [ChatMessageModel]?
    @State private var eventId = UUID().uuidString
    
    @State private var selectedMember: ContactModel?
    @State private var showMemberDetails = false
    
    let roomModel: RoomModel
    let currentUser: ContactModel?
    let onAddMemberTap: (() -> Void)?
    let onRemoveMember: ((ContactModel) -> Void)?
    let onEditGroupName: (() -> Void)?
    let onExitGroup: (() -> Void)?
    let onDeleteGroup: (() -> Void)?
    let onClearChat: (() -> Void)?
    
    @State private var showAddMemberSheet = false
    @State private var selectedToAdd: [ContactLite] = []
    @State private var invitedToAdd: [ContactLite] = []
    @State private var isEditingName = false
    @State private var editedGroupName = ""
    @State private var shouldShowAlert: Bool = false
    @State private var showClearChat = false
    @State private var showDelete = false
    @State private var exitGroup = false

    @Binding var navPath: NavigationPath
    @EnvironmentObject var callManager: CallManager

    private var admins: [ContactModel] {
        roomModel.admins.sorted { lhs, rhs in
            if lhs.userId == currentUser?.userId { return true }
            if rhs.userId == currentUser?.userId { return false }
            return lhs.fullName?.lowercased() ?? "" < rhs.fullName?.lowercased() ?? ""
        }
    }
    
    private var filteredMembers: [ContactModel] {
        let baseList: [ContactModel]

        if searchText.isEmpty {
            baseList = roomModel.activeParticipants
        } else {
            baseList = roomModel.participants.filter {
                $0.fullName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
            }
        }

        return baseList.sorted { lhs, rhs in
            // Self user on top
            if lhs.userId == currentUser?.userId { return true }
            if rhs.userId == currentUser?.userId { return false }
            return lhs.fullName?.lowercased() ?? "" < rhs.fullName?.lowercased() ?? ""
        }
    }
    
    private var leftMembers: [ContactModel] {
        let baseList: [ContactModel]

        if searchText.isEmpty {
            baseList = roomModel.leftMembers
        } else {
            baseList = roomModel.leftMembers.filter {
                $0.fullName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
            }
        }

        return baseList.sorted { lhs, rhs in
            // Self user on top
            if lhs.userId == currentUser?.userId { return true }
            if rhs.userId == currentUser?.userId { return false }
            return lhs.fullName?.lowercased() ?? "" < rhs.fullName?.lowercased() ?? ""
        }
    }

    init(
        roomModel: RoomModel,
        currentUser: ContactModel? = nil,
        sharedMediaPayload: [ChatMessageModel]?,
        roomListViewModel: RoomListViewModel,
        navPath: Binding<NavigationPath> = .constant(NavigationPath()),
        onAddMemberTap: (() -> Void)? = nil,
        onRemoveMember: ((ContactModel) -> Void)? = nil,
        onEditGroupName: (() -> Void)? = nil,
        onExitGroup: (() -> Void)? = nil,
        onDeleteGroup: (() -> Void)? = nil,
        onClearChat: (() -> Void)? = nil
    ) {
        let viewModel = DIContainer.shared.container.resolve(RoomDetailsViewModel.self, argument: roomModel)!
        viewModel.room = roomModel
        _roomDetailsViewModel = StateObject(wrappedValue: viewModel)
        
        let selectContactListViewModel = DIContainer.shared.container.resolve(SelectContactListViewModel.self)!
        selectContactListViewModel.excludedContactIds = roomModel.activeParticipants.compactMap { $0.userId }
        _selectContactListViewModel = StateObject(wrappedValue: selectContactListViewModel)
        
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: vm)
        
        self._navPath = navPath

        self.roomModel = roomModel
        self.currentUser = currentUser
        self.onAddMemberTap = onAddMemberTap
        self.onRemoveMember = onRemoveMember
        self.onEditGroupName = onEditGroupName
        self.onExitGroup = onExitGroup
        self.onDeleteGroup = onDeleteGroup
        self.onClearChat = onClearChat
        self.sharedMedia = sharedMediaPayload
        _roomListViewModel = ObservedObject(wrappedValue: roomListViewModel)
    }
    
    var body: some View {
        ZStack {
            Design.Color.backgroundColor
                    .ignoresSafeArea()
            VStack(spacing: 0) {
                headerView.background(Design.Color.backgroundColor)
                separatorView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        VStack(alignment: .leading, spacing: 16) {
                            aboutSection
                            sharedMediaSection
                            membersHeader
                            if isSearching { searchBar }
                            if let currentUserId = currentUser?.userId {
                                if isAdmin(userId: currentUserId) { addMemberButton }
                            }
                            
                            memberList
                            if !leftMembers.isEmpty {
                                Text("Left Members")
                                    .font(Design.Font.semiBold(14))
                                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                                    .padding(.top, 28)
                                    .padding(.bottom, 8)
                                
                                leftMemberList
                            }
                        }.padding(.horizontal, 20)
                        
                        bottomActions
                    }
                    .padding(.top, 16)
                }
                .background(Design.Color.tabHighlight.opacity(0.1))

            }
            .ignoresSafeArea(.all)
            .background(Design.Color.backgroundColor)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddMemberSheet) {
                NewGroupContactSelectorView(
                    viewModel: selectContactListViewModel,
                    selectedContacts: $selectedToAdd,
                    invitedContacts: $invitedToAdd,
                    onContinue: {
                        roomDetailsViewModel.inviteUsers(users: selectedToAdd)
                        showAddMemberSheet = false
                        selectedToAdd.removeAll()
                        invitedToAdd.removeAll()
                    },
                    onDismiss: {
                        selectedToAdd.removeAll()
                        invitedToAdd.removeAll()
                        showAddMemberSheet = false
                    }
                )
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            self.safeAreaInsets = geo.safeAreaInsets
                        }
                }
            )
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker { url, fileName, mimeType, filesize  in
                    if let url = url,
                       let imageData = try? Data(contentsOf: url),
                       let image = UIImage(data: imageData) {
                        downloadedImage = image
                    }
                    if let url = url, let fileName = fileName, let mimeType = mimeType {
                        chatViewModel.uploadGroupProfile(
                            fileURL: url,
                            fileName: fileName,
                            mimeType: mimeType
                        ) { uploadedUrl in
                            if let uploadedUrl = uploadedUrl {
                                roomDetailsViewModel.updateRoomImage(to: uploadedUrl.absoluteString)
                            } else {
                                self.roomDetailsViewModel.showAlertForDeniedPermission(success: true)
                            }
                            roomDetailsViewModel.updateRoomImage(to: uploadedUrl?.absoluteString ?? "")
                        }
                    }
                }
            }
            .onReceive(roomDetailsViewModel.$alertModel) { model in
                shouldShowAlert = (model != nil)
            }
            .overlay {
                if shouldShowAlert, let alertModel = roomDetailsViewModel.alertModel {
                    AlertView(model: alertModel) {
                        shouldShowAlert = false
                        roomDetailsViewModel.alertModel = nil
                    }
                }

                if showClearChat {
                    ClearChatView(
                        onClear: {
                            showClearChat = false
                            onClearChat?()
                            roomDetailsViewModel.makeConfirmClearChatAlert {
                                onClearChat?()
                            }
                        },
                        onCancel: { showClearChat = false }
                    )
                }
                
                if showDelete {
                    DeleteChatView(
                        onDelete: {
                            showDelete = false
                            roomDetailsViewModel.deleteRoom { [weak roomListViewModel] result in
                                if case .success = result {
                                    onDeleteGroup?()
                                }
                            }
                        },
                        onCancel: { showDelete = false },
                        isGroup: roomModel.isGroup
                    )
                }
                
                if exitGroup {
                    ExitGroupView(
                        onExit: {
                            exitGroup = false
                            roomDetailsViewModel.leaveRoom { _ in }
                        },
                        onExitAndClearChat: {
                            exitGroup = false
                            roomDetailsViewModel.makeConfirmClearChatAlert {
                                onClearChat?()
                            }
                            roomDetailsViewModel.leaveRoom { _ in }
                        },
                        onCancel: { exitGroup = false },
                        groupName: roomModel.name
                    )
                }

            }
        }
        .onAppear {
            print("GroupDetailsView appeared for room: \(roomModel.name)")
            print("Room ID: \(roomModel.id)")
            print("Participants: \(roomModel.participants.count)")
        }
    }
    
    struct SharedMediaThumbnailView: View {
        let message: ChatMessageModel

        @StateObject private var loader = MediaLoader()
        @State private var thumbnail: UIImage?

        var body: some View {
            Group {
                switch MediaType(rawValue: message.msgType)! {
                case .image, .gif:
                    if let img = loader.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle().fill(.gray.opacity(0.2))
                    }

                case .video:

                    if let url = loader.localURL {
                        ZStack {
                            if let thumb = thumbnail {
                                Image(uiImage: thumb).resizable().scaledToFit()
                            } else {
                                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 200)
                            }
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50)).foregroundColor(.white)
                        }
                        .onAppear {
                            if thumbnail == nil { generateVideoThumbnail(for: url) }
                        }
                    } else {
                        ZStack {
                            Rectangle().fill(.black.opacity(0.2))
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }

                case .audio:
                    ZStack {
                        Rectangle()
                            .fill(.blue.opacity(0.15))
                        Image(systemName: "waveform")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }

                case .document:
                    ZStack {
                        Rectangle()
                            .fill(.gray.opacity(0.15))
                        Image(systemName: "doc.text")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                loader.load(remoteURL: message.mediaUrl ?? "",
                            type: MediaType(rawValue: message.msgType)!)
                
            }
        }

        private func generateVideoThumbnail(for url: URL) {
            let asset = AVAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            let t = CMTime(seconds: 1, preferredTimescale: 60)
            DispatchQueue.global().async {
                if let cg = try? gen.copyCGImage(at: t, actualTime: nil) {
                    DispatchQueue.main.async { thumbnail = UIImage(cgImage: cg) }
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .topLeading) {
                Button(action: { dismiss() }) {
                    Image("back-long")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 20)
                }
                .zIndex(1)
                .background(Design.Color.backgroundColor)
                
                VStack(spacing: 8) {
                    avatarView
                    
                    VStack(alignment: .center) {
                        HStack(spacing: 12) {
                            if isEditingName {
                                TextField("Group Name", text: $editedGroupName)
                                    .font(Design.Font.semiBold(16))
                                    .foregroundColor(Design.Color.primaryTextColor)
                                    .background(Design.Color.clear)
                                    .cornerRadius(8)
                                    .transition(.opacity)
                                    .padding(.leading, 12)
                                    .padding(.vertical, 12)
                                
                                Button(action: {
                                    // Save the new group name
                                    if !editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        if editedGroupName != roomModel.name {
                                            onEditGroupName?()
                                            roomDetailsViewModel.updateRoomName(to: editedGroupName)
                                        }
                                    }
                                    isEditingName = false
                                })
                                {
                                    Image("tickmark") // Use your desired icon here
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                .padding(.trailing, 12)
                                .padding(.vertical, 12)

                            } else {
                                Text(roomModel.name)
                                    .font(Design.Font.semiBold(16))
                                    .foregroundColor(Design.Color.primaryTextColor)
                                    .padding(.leading, 12)
                                    .padding(.vertical, 12)
                                
                                if let currentUserId = currentUser?.userId, isAdmin(userId: currentUserId) {
                                    Button(action: {
                                        editedGroupName = roomModel.name
                                        isEditingName = true
                                    }) {
                                        Image("edit")
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    }
                                    .padding(.trailing, 12)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(.horizontal, 54)
                        .animation(.easeInOut, value: isEditingName)
                        
                        if isEditingName {
                            Rectangle()
                                .frame(height: 1)
                                .background(Design.Color.white)
                                .padding(.horizontal, 54)
                        }
                    }
                    
                    Text("\(roomModel.participants.count) Members")
                        .font(Design.Font.medium(12))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.4))
                                        
                    let creatorInfo = createdByText()
                    if !creatorInfo.isEmpty {
                        Text(creatorInfo)
                            .font(Design.Font.medium(12))
                            .foregroundColor(Design.Color.primaryTextColor.opacity(0.4))
                    }

                    HStack {
                        Button {
                            chatViewModel.currentRoomId = roomModel.id
                            chatViewModel.sendCallMessage(
                                callState: .outgoing,
                                isVideo: false,
                                eventId: eventId
                            ) { result in
                                switch result {
                                    case .success(let newEventId):
                                        print("livekit Message sent successfully: \(newEventId)")
                                        eventId = newEventId
                                        CallManager.shared.eventId = newEventId
                                        CallManager.shared.updateCallStatus()
                                        //                                        chatViewModel.becomeActiveCallMessageHandler(eventID: newEventId)
                                    case .failure(let error):
                                        print("Failed to send call message:", error.localizedDescription)
                                }
                            }
                            CallManager.shared.presentCall(for: roomModel)
                            CallManager.shared.isVideoCall = false
                        } label: {
                            Image("detail_audiocall")
                        }
                        .disabled(CallManager.shared.isCallInProgress())

                        
                        Button {
                            chatViewModel.currentRoomId = roomModel.id
                            chatViewModel.sendCallMessage(
                                callState: .outgoing,
                                isVideo: true,
                                eventId: eventId
                            ) { result in
                                switch result {
                                    case .success(let newEventId):
                                        print("livekit Message sent successfully: \(newEventId)")
                                        eventId = newEventId
                                        //chatViewModel.becomeActiveCallMessageHandler(eventID: newEventId)
                                        CallManager.shared.eventId = newEventId
                                        CallManager.shared.updateCallStatus()
                                    case .failure(let error):
                                        print("Failed to send call message:", error.localizedDescription)
                                }
                            }
                            CallManager.shared.presentCall(for: roomModel)
                            CallManager.shared.isVideoCall = true
                        } label: {
                            Image("detail_videocall")
                        }.padding(.horizontal, 40)
                        .disabled(CallManager.shared.isCallInProgress())

                        
                        Button(action: {
                            
                            NotificationCenter.default.post(
                                name: Notification.Name("ChatSearchTapped"),
                                object: nil
                            )
                            navPath.removeLast()
                            
                        }) {
                            Image("detail_search")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                .background(Design.Color.backgroundColor)
            }
            if roomModel.isLeft {
                HStack {
                    Spacer()
                    Text("You are no longer a participant in this group.")
                        .font(Design.Font.medium(12))
                        .foregroundColor(Design.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 52)
                        .padding(.vertical, 13.5)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Design.Color.appGradient)
            }
        }
        .padding(.top, 64)
        .background(Design.Color.backgroundColor)
    }

    // MARK: - Helper
    private func createdByText() -> String {
        // Try to find matching contact from members
        guard let creatorContact = roomModel.participants.first(where: { $0.userId == roomModel.creator }) else {
            return "" // Creator not found
        }

        // Get display name fallback
        var creatorName: String = ""
        if let fullName = creatorContact.fullName, !fullName.isEmpty {
            if let currentUserId = currentUser?.userId, currentUserId == roomModel.creator {
                creatorName = "You"
            } else {
                creatorName = fullName
            }
        } else {
            creatorName = creatorContact.phoneNumber
        }
        
        guard !creatorName.isEmpty else {
            return "" // No valid name or phone
        }

        // Format date if available
        if let createdAt = roomModel.createdAt {
            let createdAtDate = Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            let createdAtDateString = formatter.string(from: createdAtDate)
            return "Created by \(creatorName) on \(createdAtDateString)"
        } else {
            return "Created by \(creatorName)"
        }
    }
    
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) { // Align content to bottomTrailing for edit button
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .onTapGesture {
                        showFullScreen = true
                    }
                    .fullScreenCover(isPresented: $showFullScreen) {
                        FullScreenImageView(source: .uiImage(image),
                                            userName: "",
                                            timeText: "",
                                            isPresented: $showFullScreen)
                        .zIndex(1)
                    }
                
                // Show edit button only if user is admin
                if let currentUserId = currentUser?.userId, isAdmin(userId: currentUserId) {
                    Button(action: {
                        isImagePickerPresented = true
                    }) {
                        Circle()
                            .fill(Design.Color.appGradient)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image("edit-light")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.white)
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 2)
                    }
                }
            } else {
                placeholderAvatar
                    .onAppear {
                        guard downloadedImage == nil else { return }
                        if let avatarUrl = roomModel.avatarUrl {
                            MediaCacheManager.shared.getMedia(
                                url: avatarUrl, // keep MXC
                                type: .image,
                                progressHandler: { progress in
                                    downloadProgress = progress
                                },
                                completion: { result in
                                    switch result {
                                    case .success(let imagePath):
                                        // Build a proper file URL from either a "file://" string or raw path
                                        let fileURL: URL = {
                                            if let u = URL(string: imagePath), u.scheme == "file" {
                                                return u
                                            } else {
                                                return URL(fileURLWithPath: imagePath)
                                            }
                                        }()
                                        
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            autoreleasepool {
                                                do {
                                                    // 1) Exists & not a directory
                                                    var isDir: ObjCBool = false
                                                    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                                          !isDir.boolValue else {
                                                        throw NSError(domain: "AvatarImage", code: 6001,
                                                                      userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                                    }
                                                    
                                                    // 2) Type-gate: only decode images (prevents PDF/MP4/MP3 hitting ImageIO)
                                                    if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                                       !ut.conforms(to: .image) {
                                                        throw NSError(domain: "AvatarImage", code: 6002,
                                                                      userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                                    }
                                                    
                                                    // 3) Downsample via ImageIO (low memory)
                                                    let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                                    var ui: UIImage? = nil
                                                    if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                                        let opts: [CFString: Any] = [
                                                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                            kCGImageSourceShouldCacheImmediately: true,
                                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                                            kCGImageSourceThumbnailMaxPixelSize: 1024 // adjust as needed
                                                        ]
                                                        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                                            ui = UIImage(cgImage: cg)
                                                        }
                                                    }
                                                    
                                                    // 4) Fallbacks
                                                    if ui == nil { ui = UIImage(contentsOfFile: fileURL.path) }
                                                    if ui == nil {
                                                        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                                        ui = UIImage(data: data)
                                                    }
                                                    guard var img = ui else {
                                                        throw NSError(domain: "AvatarImage", code: 6003,
                                                                      userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                                    }
                                                    
                                                    if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                                    
                                                    DispatchQueue.main.async { downloadedImage = img }
                                                    
                                                } catch {
                                                    print("❌ Failed to load avatar image: \(error.localizedDescription) — \(fileURL.path)")
                                                }
                                            }
                                        }
                                        
                                    case .failure(let error):
                                        print("❌ Failed to load avatar: \(error)")
                                    }
                                }
                            )
                        }
                    }
            }
        }
    }

    private var placeholderAvatar: some View {
        return ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(roomModel.randomeProfileColor.opacity(0.3))
                Text(getInitials(from: roomModel.name))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
            }
            
            if let currentUserId = currentUser?.userId, isAdmin(userId: currentUserId) {
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    Circle()
                        .fill(Design.Color.appGradient)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image("edit-light")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 2)
                }
            }
        }
        .frame(width: 100, height: 100)
    }
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("No about info available")
                .font(Design.Font.regular(14))
                .foregroundColor(Design.Color.primaryTextColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(Design.Color.darkgrayColor))
        .cornerRadius(10)
    }
    
    var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Media")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryTextColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {

                    if let media = sharedMedia, !media.isEmpty {

                        ForEach(media, id: \.self) { item in
                            SharedMediaThumbnailView(message: item)
                                .onTapGesture {
                                    openFullPreview(for: item)
                                }
                        }

                    } else {
                        Text("No shared media")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.primaryTextColor)
                    }

                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(Design.Color.darkgrayColor))
        .cornerRadius(10)
    }
    
    func openFullPreview(for item: ChatMessageModel) {
        let messageId = item.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(
                name: .deepLinkScrollToMessage,
                object: nil,
                userInfo: ["messageId": messageId]
            )
        }
    }
    
    struct ImageOverlayView: View {
        let url: String?
        var size: CGFloat = 88
        @State private var downloadedImage: UIImage?
        @State private var showFullScreen: Bool = false
        @State private var downloadProgress: Double = 0.0
        
        var body: some View {
            Group {
                if let image = downloadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onTapGesture {
                            showFullScreen = true
                        }
                        .fullScreenCover(isPresented: $showFullScreen) {
                            FullScreenImageView(source: .uiImage(image),
                                                userName: "",
                                                timeText: "",
                                                isPresented: $showFullScreen)
                            .zIndex(1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)
                        .overlay(
                            ProgressView(value: downloadProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .opacity(downloadProgress == 1.0 ? 0 : 1)
                        )
                }
            }
            .onAppear {
                guard downloadedImage == nil else { return }
                if let imageUrl = url {
                    downloadImage(from: imageUrl)
                }
            }
        }
        
        private func downloadImage(from url: String) {
            // Assuming MediaCacheManager or similar is available
            MediaCacheManager.shared.getMedia(
                url: url,
                type: .image,
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        downloadProgress = progress
                    }
                }) { result in
                    switch result {
                    case .success(let imagePath):
                        // Build a safe file URL from either "file://…" or raw path
                        let fileURL: URL = {
                            if let u = URL(string: imagePath), u.scheme == "file" {
                                return u
                            } else {
                                return URL(fileURLWithPath: imagePath)
                            }
                        }()
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            autoreleasepool {
                                do {
                                    // 1) Exists & not a directory
                                    var isDir: ObjCBool = false
                                    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                          !isDir.boolValue else {
                                        throw NSError(domain: "ImageOverlayView", code: 7001,
                                                      userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                    }
                                    
                                    // 2) Type-gate: only decode images
                                    if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                       !ut.conforms(to: .image) {
                                        throw NSError(domain: "ImageOverlayView", code: 7002,
                                                      userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                    }
                                    
                                    // 3) Downsample via ImageIO (low memory)
                                    let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                    var ui: UIImage? = nil
                                    if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                        let opts: [CFString: Any] = [
                                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceShouldCacheImmediately: true,
                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 2048
                                        ]
                                        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                            ui = UIImage(cgImage: cg)
                                        }
                                    }
                                    
                                    // 4) Fallbacks
                                    if ui == nil { ui = UIImage(contentsOfFile: fileURL.path) }
                                    if ui == nil {
                                        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                        ui = UIImage(data: data)
                                    }
                                    guard var img = ui else {
                                        throw NSError(domain: "ImageOverlayView", code: 7003,
                                                      userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                    }
                                    
                                    if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                    
                                    DispatchQueue.main.async { downloadedImage = img }
                                    
                                } catch {
                                    print("ImageOverlayView: image decode error — \(error.localizedDescription) | \(fileURL.path)")
                                }
                            }
                        }
                        
                    case .failure(let error):
                        print("ImageOverlayView: Failed to load image — \(error)")
                    }
                }
        }
    }

    private var membersHeader: some View {
        HStack {
            Text("\(roomModel.participants.count) Members")
                .font(Design.Font.semiBold(14))
                .foregroundColor(Design.Color.primaryTextColor)
            Spacer()
            Button(action: {
                isSearching.toggle()
                searchText = ""
            }) {
                Image(isSearching ? "transparent-cross" : "search")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image("search")
                .resizable()
                .frame(width: 20, height: 20)
                .padding(.leading, 20)
                .padding(.vertical, 12)
            
            TextField("Search numbers & names", text: $searchText)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 20)
                .padding(.vertical, 12)
        }
        .background(Color(Design.Color.darkgrayColor))
        .cornerRadius(10)
    }

    private var addMemberButton: some View {
        Button {
            showAddMemberSheet = true
            selectedToAdd = []
            invitedToAdd = []
        } label: {
            HStack(spacing: 12) {
                Image("add")
                    .resizable()
                    .frame(width: 32, height: 32)
                
                Text("Add Member")
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.primaryTextColor)
            }
            .padding(.vertical, 8)
        }
    }

    private var memberList: some View {
        VStack(spacing: 16) {
            ForEach(Array(filteredMembers.enumerated()), id: \.offset) { _, member in
                if let userId = member.userId,
                   let currentUserId = currentUser?.userId,
                   !member.phoneNumber.isEmpty {

                    GroupMemberRow(
                        member: member,
                        isAdmin: isAdmin(userId: userId),
                        showActions: !isAdmin(userId: userId) && isAdmin(userId: currentUserId),
                        isCurrentUser: userId == currentUserId
                    ) {
                        present(roomDetailsViewModel.makeConfirmKickAlert(for: member))
                    } onTap: { tappedMember in
                        // Show bottom sheet instead of navigating
                        selectedMember = tappedMember
                        showMemberDetails = true
                    }
                }
            }
        }
        .sheet(isPresented: $showMemberDetails) {
            if let member = selectedMember {
                MemberDetailsBottomSheet(
                    member: member,
                    currentUser: currentUser,
                    isAdmin: isAdmin(userId: member.userId ?? ""),
                    canMakeAdmin:  {
                        guard let currentUserId = currentUser?.userId else { return false }
                        return isAdmin(userId: currentUserId)
                    }(),
                    onMessage: {
                        showMemberDetails = false
                        redirectToUserChat(member: member)
                    },
                    onMakeAdmin: {
                        // Handle make admin action
                        print("Make admin tapped for: \(member.fullName ?? "")")
                        showMemberDetails = false
                    },
                    onRemove: {
                        showMemberDetails = false
                        present(roomDetailsViewModel.makeConfirmKickAlert(for: member))
                    },
                    onDismiss: {
                        showMemberDetails = false
                        selectedMember = nil
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
            }
        }
    }
    
    func redirectToUserDetail(member: ContactModel) {
        if let room = roomListViewModel.getDirectRoomModel(for: member) {
            // navigate directly
            roomListViewModel.selectedRoom = room
            navPath.append(NavigationTarget.userDetails(room: room,
                                                        user: member,
                                                        sharedMedia: []))
            
        } else {
            print("new room is created")
            // create new chat
            roomListViewModel.startChat(
                with: member.userId ?? "",
                currentUserId: roomListViewModel.currentUser?.userId ?? ""
            ) { newRoom in
                roomListViewModel.selectedRoom = newRoom
                //newRoom?.opponent?.avatarURL = member.avatarURL
                navPath.append(
                    NavigationTarget.userDetails(
                        room: newRoom!,
                        user: member,
                        sharedMedia: []
                    )
                )
            }
        }
    }
    
    func redirectToUserChat(member: ContactModel) {
        if let room = roomListViewModel.getDirectRoomModel(for: member) {
            // navigate directly
            roomListViewModel.selectedRoom = room
             navPath.append(NavigationTarget.chat(room: room))
        } else {
            print("nre room is created")
            // create new chat
            roomListViewModel.startChat(
                with: member.userId ?? "",
                currentUserId: roomListViewModel.currentUser?.userId ?? ""
            ) { newRoom in
                roomListViewModel.selectedRoom = newRoom
                newRoom?.opponent?.avatarURL = member.avatarURL
                print(" newRoom?.opponent?.avatarURL ",  newRoom?.opponent?.avatarURL ?? "")

                navPath.append(NavigationTarget.chat(room: newRoom!))
            }
        }
    }

    private var leftMemberList: some View {
        VStack(spacing: 16) {
            ForEach(Array(leftMembers.enumerated()), id: \.offset) { _, member in        // <-- value array, not Binding
                if let userId = member.userId,
                   let currentUserId = currentUser?.userId {

                    GroupMemberRow(
                        member: member,
                        isAdmin: false,
                        showActions: false,
                        isCurrentUser: userId == currentUserId,
                        onRemove: nil,
                        onTap: { tappedMember in
                            // Show bottom sheet for left members too
                            selectedMember = tappedMember
                            showMemberDetails = true
                        }
                    )
                }
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 0) {
            
            Button(action: {
                $navPath.wrappedValue.append(NavigationTarget.notificationSettings(room: roomModel))
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image(roomModel.isMuted ? "notification-unmute" : "notification-mute")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                    Text("Notifications")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Button(action: {
                roomModel.isFavorite.toggle()
                roomDetailsViewModel.toggeleFavorite(for: roomModel)
            }) {
                HStack(spacing: 12) {
                    Image(roomModel.isFavorite ? "un-favorite" : "favorite")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                    Text(roomModel.isFavorite ? "Remove from favorites" : "Add to favorites")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                    Spacer()
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Button(action: {
                showClearChat = true
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image("broom")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                    
                    Text("Clear Chat")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Spacer(minLength: 12)

            if roomModel.isLeft {
                Button {
                    showDelete = true
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        Image("logout")
                        Text("Delete Group")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.destructiveRed)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }
                .background(Color(Design.Color.darkgrayColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Design.Color.destructiveRed, lineWidth: 1)
                )
                .padding(.horizontal, 32)
            } else if let currentUserId = currentUser?.userId, isAdmin(userId: currentUserId) {
                Button(action: {
                    showDelete = true
                }) {
                    HStack(alignment: .bottom, spacing: 8) {
                        Spacer()
                        Image("logout")
                            .frame(width: 16, height: 16)
                        Text("Delete Group")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.destructiveRed)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }.background(Color(Design.Color.darkgrayColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Design.Color.destructiveRed, lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
            } else {
                Button(action: {
                    exitGroup = true
                }) {
                    HStack(alignment: .bottom, spacing: 8) {
                        Spacer()
                        Image("logout")
                            .frame(width: 16, height: 16)
                        Text("Exit Group")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.destructiveRed)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }
                .background(Color(Design.Color.darkgrayColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Design.Color.destructiveRed.opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 20)
        .background(footerBackground)
    }
    
    // MARK: - Bubble Background
    private var footerBackground: some View {
        CustomRoundedCornersShape(
            radius: 16,
            roundedCorners: [.topRight, .topLeft]
        )
        .fill(Design.Color.backgroundColor)
    }
    
    @ViewBuilder
    private func separatorView() -> some View {
        Rectangle()
            .fill(Design.Color.appGradient.opacity(0.12))
            .frame(height: 1)
    }
    
    func isAdmin(userId: String) -> Bool {
        admins.contains(where: { $0.userId == userId })
    }
    
    private func present(_ model: AlertViewModel) {
        roomDetailsViewModel.alertModel = model
        shouldShowAlert = true
    }
}

struct GroupMemberRow: View {
    let member: ContactModel
    let isAdmin: Bool
    let showActions: Bool
    let isCurrentUser: Bool
    let onRemove: (() -> Void)?
    let onTap: ((ContactModel) -> Void)?
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            
            let memberName: String = {
                if isCurrentUser { return "You" }
                if let fullName = member.fullName, !fullName.isEmpty { return fullName }
                if let displayName = member.displayName, !displayName.isEmpty { return displayName }
                return member.phoneNumber
            }()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(memberName)
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.primaryTextColor)
                
                Text(member.phoneNumber)
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.4))
            }
               
            Spacer()

            if isAdmin {
                Spacer()

                Text("Group Admin")
                    .font(Design.Font.medium(12))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Design.Color.tabHighlight.opacity(0.2))
                    .cornerRadius(2)
            }
                   
            if showActions {
                Spacer()

                Button(action: { onRemove?() }) {
                    Text("Remove")
                        .font(Design.Font.medium(12))
                        .foregroundColor(Design.Color.dangerBackground)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(Design.Color.dangerBackground.opacity(0.12))
                        .cornerRadius(2)
                }
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            if !isCurrentUser {
                onTap?(member)
            }
        }
    }
    
    private var avatarView: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                initialsView
            }
        }.onAppear {
            guard downloadedImage == nil else { return } // prevent re-download
            if let httpUrl = member.avatarURL, !httpUrl.isEmpty {
                MediaCacheManager.shared.getMedia(
                    url: httpUrl,
                    type: .image,
                    progressHandler: { progress in
                        downloadProgress = progress
                    },
                    completion: { result in
                        switch result {
                        case .success(let imagePath):
                            // Build a safe file URL from either "file://…" or raw path
                            let fileURL: URL = {
                                if let u = URL(string: imagePath), u.scheme == "file" {
                                    return u
                                } else {
                                    return URL(fileURLWithPath: imagePath)
                                }
                            }()
                            
                            DispatchQueue.global(qos: .userInitiated).async {
                                autoreleasepool {
                                    do {
                                        // 1) Exists & not a directory
                                        var isDir: ObjCBool = false
                                        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                              !isDir.boolValue else {
                                            throw NSError(domain: "Media", code: 8001,
                                                          userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                        }
                                        
                                        // 2) Type-gate: only decode images (prevents PDF/MP4/MP3 from hitting ImageIO)
                                        if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                           !ut.conforms(to: .image) {
                                            throw NSError(domain: "Media", code: 8002,
                                                          userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                        }
                                        
                                        // 3) Downsample via ImageIO (low memory)
                                        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                        var ui: UIImage? = nil
                                        if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                            let opts: [CFString: Any] = [
                                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                kCGImageSourceShouldCacheImmediately: true,
                                                kCGImageSourceCreateThumbnailWithTransform: true,
                                                kCGImageSourceThumbnailMaxPixelSize: 1536 // tweak as needed
                                            ]
                                            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                                ui = UIImage(cgImage: cg)
                                            }
                                        }
                                        
                                        // 4) Fallbacks (still off-main)
                                        if ui == nil { ui = UIImage(contentsOfFile: fileURL.path) }
                                        if ui == nil {
                                            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                            ui = UIImage(data: data)
                                        }
                                        guard var img = ui else {
                                            throw NSError(domain: "Media", code: 8003,
                                                          userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                        }
                                        
                                        if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                        
                                        DispatchQueue.main.async { downloadedImage = img }
                                        
                                    } catch {
                                        print("Media decode error — \(error.localizedDescription) | \(fileURL.path)")
                                    }
                                }
                            }
                            
                        case .failure(let error):
                            print("Failed to download media: \(error)")
                        }
                    }
                )
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.gray.opacity(0.2))
        .clipShape(Circle())
    }
    
    private var initialsView: some View {
        return Text(getInitials(from: member.fullName ?? ""))
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(member.randomeProfileColor.opacity(0.3))
            .clipShape(Circle())
    }
}
// MARK: - Member Details Bottom Sheet
struct MemberDetailsBottomSheet: View {
    let member: ContactModel
    let currentUser: ContactModel?
    let isAdmin: Bool
    let canMakeAdmin: Bool
    let onMessage: () -> Void
    let onMakeAdmin: () -> Void
    let onRemove: () -> Void
    let onDismiss: () -> Void
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
              
                // Avatar
                avatarView
                    .padding(.top, 32)
                
                // Name
                Text(memberName)
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .padding(.top, 12)
                
                // Phone Number
                Text(member.phoneNumber)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                    .padding(.top, 2)
                
                // Action Buttons
                actionButtons
                    .padding(.top, 20)
                
                // Admin Actions
                adminActions
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(Design.Color.darkgrayColor))
            .clipShape(TopCornersRounded(radius: 20))
            .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear {
            loadAvatar()
        }
    }
    struct TopCornersRounded: Shape {
        var radius: CGFloat = 20

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }

    
    private var memberName: String {
        if let fullName = member.fullName, !fullName.isEmpty {
            return fullName
        } else if let displayName = member.displayName, !displayName.isEmpty {
            return displayName
        } else {
            return member.phoneNumber
        }
    }
    
    private var avatarView: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 77, height: 77)
                    .clipShape(Circle())
            } else {
                Text(getInitials(from: member.fullName ?? ""))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(member.randomeProfileColor.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 60) {
            // Message Button
            actionButton(
                imageName: "group_messages",
                label: "",
                action: onMessage
            )
            
            // Audio Call Button
            actionButton(
                imageName: "call_icon",
                label: "",
                action: {
                    // Handle audio call
                }
            )
            
            // Video Call Button
            actionButton(
                imageName: "video_icon",
                label: "",
                action: {
                    // Handle video call
                }
            )
        }
        .frame(height: 80)
    }
    
    private func actionButton(imageName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Design.Color.appGradient)
                        .frame(width: 56, height: 56)
                    
                    Image(imageName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                }
                if !label.isEmpty { // Only show if label exists
                    
                    Text(label)
                        .font(Design.Font.regular(12))
                        .foregroundColor(Design.Color.primaryTextColor)
                }
            }
        }
    }
    
    @ViewBuilder
    private var adminActions: some View {
        VStack(spacing: 10) {
            Button(action: onMakeAdmin) {
                HStack(spacing: 20) {
                    Image("admin_user")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Design.Color.primaryTextColor)
                        .frame(width: 20, height: 20)
                    
                    Text("Make group admin")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .background(Color(Design.Color.darkgrayColor))
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: onRemove) {
                HStack(spacing: 16) {
                    Image("remove_user")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Design.Color.destructiveRed)
                        .frame(width: 20, height: 20)
                    
                    Text("Remove from group")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.destructiveRed)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .background(Color(Design.Color.darkgrayColor))
            }
            .buttonStyle(PlainButtonStyle())
            
        }
        .padding(.horizontal, 60)
    }
    
    private func loadAvatar() {
        guard downloadedImage == nil else { return }
        guard let httpUrl = member.avatarURL, !httpUrl.isEmpty else { return }
        
        MediaCacheManager.shared.getMedia(
            url: httpUrl,
            type: .image,
            progressHandler: { progress in
                downloadProgress = progress
            },
            completion: { result in
                switch result {
                case .success(let imagePath):
                    let fileURL: URL
                    if let u = URL(string: imagePath), u.scheme == "file" {
                        fileURL = u
                    } else {
                        fileURL = URL(fileURLWithPath: imagePath)
                    }
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            do {
                                var isDir: ObjCBool = false
                                guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                      !isDir.boolValue else {
                                    return
                                }
                                
                                if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                   !ut.conforms(to: .image) {
                                    return
                                }
                                
                                let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                var ui: UIImage? = nil
                                
                                if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                    let opts: [CFString: Any] = [
                                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceShouldCacheImmediately: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 1536
                                    ]
                                    if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                        ui = UIImage(cgImage: cg)
                                    }
                                }
                                
                                if ui == nil {
                                    ui = UIImage(contentsOfFile: fileURL.path)
                                }
                                
                                if ui == nil {
                                    let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                    ui = UIImage(data: data)
                                }
                                
                                guard var img = ui else { return }
                                
                                if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() {
                                    img = prepped
                                }
                                
                                DispatchQueue.main.async {
                                    downloadedImage = img
                                }
                                
                            } catch {
                                print("Media decode error — \(error.localizedDescription)")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("Failed to download media: \(error)")
                }
            }
        )
    }
}
