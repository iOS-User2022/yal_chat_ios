//
//  GroupDetailsView.swift
//  YAL
//
//  Created by Vishal Bhadade on 27/05/25.
//

import SwiftUI

struct GroupDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var safeAreaInsets: EdgeInsets = .init()
    @StateObject private var roomDetailsViewModel: RoomDetailsViewModel
    @StateObject private var selectContactListViewModel: SelectContactListViewModel
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    @State private var isImagePickerPresented = false
    @StateObject private var chatViewModel: ChatViewModel
    @State private var showFullScreen = false
    @State var sharedMedia: [ChatMessageModel]?

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
    @State private var showEditSuccessAlert: Bool = false
    @Binding var navPath: NavigationPath

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
            baseList = roomModel.participants
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
        selectContactListViewModel.excludedContactIds = roomModel.participants.compactMap { $0.userId }
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
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
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
                                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
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
            .background(Design.Color.white)
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
                                showEditSuccessAlert = true
                            }
                            roomDetailsViewModel.updateRoomImage(to: uploadedUrl?.absoluteString ?? "")
                        }
                    }
                }
            }
            
            if showEditSuccessAlert, let alertModel = roomDetailsViewModel.alertModel {
                AlertView(model: alertModel) {
                    showEditSuccessAlert = false
                }
            }

            // Custom Alert Overlay
            if showEditSuccessAlert, let alertModel = roomDetailsViewModel.alertModel {
                AlertView(model: alertModel) {
                    showEditSuccessAlert = false
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
                
                VStack(spacing: 8) {
                    avatarView
                    
                    VStack(alignment: .center) {
                        HStack(spacing: 12) {
                            if isEditingName {
                                TextField("Group Name", text: $editedGroupName)
                                    .font(Design.Font.semiBold(16))
                                    .foregroundColor(Design.Color.primaryText)
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
                                            roomDetailsViewModel.updateRoomName(to: editedGroupName) { result in
                                                showEditSuccessAlert = true
                                            }

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
                                    .foregroundColor(Design.Color.primaryText)
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
                        .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    
                    
                    let creatorInfo = createdByText()
                    if !creatorInfo.isEmpty {
                        Text(creatorInfo)
                            .font(Design.Font.medium(12))
                            .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    }
                    HStack {
                        Button(action: {
                            
                            NotificationCenter.default.post(
                                    name: Notification.Name("ChatSearchTapped"),
                                    object: nil
                                )
                            navPath.removeLast()
                            
                        }) {
                            Image("Search")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
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
        return ZStack {
            Circle().fill(roomModel.randomeProfileColor.opacity(0.3))
            Text(getInitials(from: roomModel.name))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
        }
        .frame(width: 100, height: 100)
    }
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("No about info available")
                .font(Design.Font.regular(14))
                .foregroundColor(Design.Color.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Design.Color.white.opacity(0.6))
        .cornerRadius(10)
    }
    
    var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared Media")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if let media = sharedMedia {
                        ForEach(media, id: \.self) { image in
                            ImageOverlayView(url: image.mediaUrl)
                        }
                    } else {
                        Text("No about info available")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.primaryText)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Design.Color.white.opacity(0.6))
        .cornerRadius(10)
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
                        let fileURL: URL = imagePath.hasPrefix("file://")
                        ? URL(string: imagePath)!
                        : URL(fileURLWithPath: imagePath)
                        
                        if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                            // Fallback to loading Data if path fails
                            guard let data = try? Data(contentsOf: fileURL) else { return nil }
                            return UIImage(data: data)
                        }() {
                            DispatchQueue.main.async {
                                downloadedImage = uiImage
                            }
                        }
                    case .failure(let error):
                        print("ImageOverlayView: Failed to load image: \(error)")
                    }
                }
        }
    }

    private var membersHeader: some View {
        HStack {
            Text("\(roomModel.participants.count) Members")
                .font(Design.Font.semiBold(14))
                .foregroundColor(Design.Color.primaryText)
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
        .background(Design.Color.lightWhiteBackground)
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
                    .foregroundColor(Design.Color.primaryText)
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
                        roomDetailsViewModel.kickOutUser(member)
                    }
                }
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
                        onRemove: nil
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
                        .frame(width: 16, height: 16)
                    Text("Notifications")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Button(action: {
                roomModel.isFavorite.toggle()
            }) {
                HStack(spacing: 12) {
                    Image(roomDetailsViewModel.isFavorite ? "un-favorite" : "favorite")
                    Text(roomDetailsViewModel.isFavorite ? "Remove from favorites" : "Add to favorites")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    Spacer()
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Button(action: {
                onClearChat?()
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image("broom")
                        .frame(width: 16, height: 16)
                    
                    Text("Clear Chat")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()
            
            Spacer(minLength: 12)

            if roomModel.isLeft {
                Button {
                    roomDetailsViewModel.deleteRoom() { result in
                        switch result {
                        case .success:
                            print("Room deleted successfully")
                            onDeleteGroup?()
                        case .failure(let error):
                            print("Failed to delete room: \(error)")
                        }
                    }
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
            } else if let currentUserId = currentUser?.userId, isAdmin(userId: currentUserId) {
                Button {
                    roomDetailsViewModel.deleteRoom { result in
                        switch result {
                        case .success:
                            // Show success UI, pop view, show toast, etc.
                            print("Room deleted successfully")
                            onDeleteGroup?()
                        case .failure(let error):
                            // Show error UI
                            print("Failed to delete room: \(error)")
                        }
                    }
                } label: {
                    
                    Button(action: {
                       
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
                    }
                    .background(Design.Color.lightGrayBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 32)
                }
            } else {
                Button {
                    roomDetailsViewModel.leaveRoom()
                } label: {
                    Button(action: {
                       
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
                    .background(Design.Color.lightGrayBackground)
                    .cornerRadius(8)
                    .padding(.horizontal, 32)
                }
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
        .fill(Design.Color.white)
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
}

struct GroupMemberRow: View {
    let member: ContactModel
    let isAdmin: Bool
    let showActions: Bool
    let isCurrentUser: Bool
    let onRemove: (() -> Void)?
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
                    .foregroundColor(Design.Color.primaryText)
                
                Text(member.phoneNumber)
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
            }
               
            Spacer()

            if isAdmin {
                Spacer()

                Text("Group Admin")
                    .font(Design.Font.medium(12))
                    .foregroundColor(Design.Color.primaryText)
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
                            print("❌ Failed to download media: \(error)")
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

