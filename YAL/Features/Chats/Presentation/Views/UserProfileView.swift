//
//  UserProfileView.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/06/25.
//


import SwiftUI

struct UserProfileView: View {
    var onBack: () -> Void
    var onBlock: () -> Void
    var onUnBlock: () -> Void
    var onDeleteChat: () -> Void
    var onClearChat: () -> Void

    @State private var topInsets: CGFloat = 0
    @StateObject private var viewModel: UserProfileViewModel
    let roomModel: RoomModel
    @Binding var navPath: NavigationPath
    @State var sharedMedia: [ChatMessageModel]?
    
    @State private var showBlock = false
    @State private var showUnBlock = false
    @State private var showDelete = false

    init(user: ContactModel,
         room: RoomModel,
         sharedMediaPayload: [ChatMessageModel]?,
         navPath: Binding<NavigationPath> = .constant(NavigationPath()),
         onBack: @escaping () -> Void,
         onBlock: @escaping () -> Void,
         onUnBlock: @escaping () -> Void,
         onDeleteChat: @escaping () -> Void,
         onClearChat: @escaping () -> Void) {
        let vm = DIContainer.shared.container.resolve(UserProfileViewModel.self, arguments: user, room)!
        _viewModel = StateObject(wrappedValue: vm)
        self.roomModel = room
        self.sharedMedia = sharedMediaPayload
        self._navPath = navPath
        self.onBack = onBack
        self.onBlock = onBlock
        self.onUnBlock = onUnBlock
        self.onDeleteChat = onDeleteChat
        self.onClearChat = onClearChat
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerSection
                ScrollView {
                    VStack(spacing: 16) {
                        aboutSection
                        sharedMediaSection
                        groupsSection
                        actionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                }
            }
            .background(Design.Color.appGradient.opacity(0.12))
            .ignoresSafeArea(.all)
            .onAppear {
                topInsets = 0
            }
            .overlay{
                if showBlock {
                    BlockConfirmationView(
                        userName: roomModel.name,
                        onBlock: {
                            roomModel.isBlocked = true
                            showBlock = false
                            onBlock()
                        },
                        onCancel: { showBlock = false }
                    )
                }
                
                if showUnBlock {
                    UnblockConfirmationView(
                        userName: roomModel.name,
                        onUnblock: {
                            roomModel.isBlocked = false
                            showUnBlock = false
                            onUnBlock()
                        },
                        onCancel: { showUnBlock = false }
                    )
                }
                if showDelete {
                    DeleteChatView(
                        onDelete: {
                            onDeleteChat()
                            showDelete = false
                        },
                        onCancel: { showDelete = false },
                        isGroup: roomModel.isGroup
                    )
                }
            }
            .overlay{
                if showBlock {
                    BlockConfirmationView(
                        userName: roomModel.name,
                        onBlock: {
                            roomModel.isBlocked = true
                            showBlock = false
                            onBlock()
                        },
                        onCancel: { showBlock = false }
                    )
                }
                
                if showUnBlock {
                    UnblockConfirmationView(
                        userName: roomModel.name,
                        onUnblock: {
                            roomModel.isBlocked = false
                            showUnBlock = false
                            onUnBlock()
                        },
                        onCancel: { showUnBlock = false }
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    var headerSection: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .center, spacing: 0) {
                UserImageView(url: viewModel.userDetails?.avatarURL, size: 100, roomModel: roomModel)
                Spacer().frame(height: 8)
                
                if let displayName = viewModel.userDetails?.fullName {
                    Text(displayName)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(height: 4)
                }

                if let phoneNumber = viewModel.userDetails?.phoneNumber {
                    Text(phoneNumber)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let email = viewModel.userDetails?.emailAddresses.first {
                    Spacer().frame(height: 4)
                    Text(email)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Spacer().frame(height: 20)
                HStack {
                    Button(action: {
                        // Pop UserProfileView to return to ChatView and trigger search
                        NotificationCenter.default.post(
                                name: Notification.Name("ChatSearchTapped"),
                                object: nil
                            )
                        navPath.removeLast()
                        // Note: ChatView will handle isSearching via onReturnFromProfile
                    }) {
                        Image("Search")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, topInsets + 67)
            .padding(.bottom, 20)
            .padding(.horizontal, 54)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            VStack {
                Button(action: {
                    onBack()
                }) {
                    Image("back-long")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                }
                .padding(.leading, 10)
                .frame(width: 40, height: 40)
            }
            .padding(.top, topInsets + 67)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Design.Color.white)
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.userDetails?.statusMessage ?? "No about info available")
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
                        Text("no media is shared")
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

    var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.sharedGroups.count) Group\(viewModel.sharedGroups.count == 1 ? "" : "s") in common")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryText)
            
            ForEach(viewModel.sharedGroups.prefix(3), id: \.id) { group in
                HStack(spacing: 12) {
                    UserImageView(url: group.avatarUrl, size: 40, roomModel: group).disabled(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.primaryText)
                        Text(group.participants.map { $0.firstNameOrFallback }.joined(separator: ", "))
                            .font(Design.Font.regular(12))
                            .foregroundColor(Design.Color.primaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            
            if let firstName = viewModel.userDetails?.firstNameOrFallback {
                Button {
                    // Create new group with this user
                } label: {
                    HStack(spacing: 12) {
                        Image("new-group")
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        
                        Text("Create new Group with \(firstName)")
                            .font(Design.Font.semiBold(14))
                            .foregroundColor(Design.Color.primaryText)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Design.Color.white.opacity(0.6))
        .cornerRadius(10)
    }

    var actionsSection: some View {
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
                viewModel.toggeleFavorite(for: roomModel)
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image(viewModel.isFavorite ? "un-favorite" : "favorite")
                        .frame(width: 16, height: 16)
                    Text(viewModel.isFavorite ? "Remove from favorites" : "Add to favorites")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
            Divider()

            Button(action: {
                onClearChat()
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
            if roomModel.isBlocked {
                       Button(action: {
                           showUnBlock = true
                       }) {
                           HStack(alignment: .bottom, spacing: 12) {
                               Image("shield-cross-blue")
                                   .frame(width: 16, height: 16)
                               Text("Unblock")
                                   .font(Design.Font.regular(14))
                                   .foregroundColor(Design.Color.primaryText.opacity(0.6))
                               Spacer()
                           }
                           .padding(.horizontal, 32)
                           .padding(.vertical, 20)
                       }
            } else {
                Button(action: {
                    showBlock = true
                }) {
                    HStack(alignment: .bottom, spacing: 12) {
                        Image("block-red")
                            .frame(width: 16, height: 16)
                        Text("Block")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.destructiveRed)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
            }

            Button(action: {
                showDelete = true
            }) {
                HStack(alignment: .bottom, spacing: 8) {
                    Spacer()
                    Image("delete-account")
                        .frame(width: 16, height: 16)
                    Text("Delete Chat")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.destructiveRed)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
            }
            .background(Design.Color.lightGrayBackground)
            .cornerRadius(8)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

private struct UserImageView: View {
    let url: String?
    var size: CGFloat = 100
    @State private var downloadedImage: UIImage?
    @State private var showFullScreen: Bool = false
    @State private var downloadProgress: Double = 0.0
    let roomModel: RoomModel

    var body: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
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
            } else {
                Text(getInitials(from: roomModel.name))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
                    .frame(width: 48, height: 48)  // Set the circle size
                    .background(roomModel.randomeProfileColor.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            guard downloadedImage == nil else { return }
            if let avatarUrl = roomModel.avatarUrl {
                MediaCacheManager.shared.getMedia(
                    url: avatarUrl,
                    type: .image,
                    progressHandler: { _ in }
                ) { result in
                    switch result {
                    case .success(let imagePath):
                        // imagePath can be "/var/.../image.jpg" or "file:///var/.../image.jpg"
                        let fileURL: URL = imagePath.hasPrefix("file://")
                            ? URL(string: imagePath)!
                            : URL(fileURLWithPath: imagePath)

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
                        print("ChatHeaderView: failed to load image \(error)")
                    }
                }
            }
        }
    }
}

extension ContactModel {
    var firstNameOrFallback: String {
        fullName?.split(separator: " ").first.map(String.init) ?? phoneNumber
    }
}

struct NotificationSettingsView: View {
    @State private var isMuted: Bool = false
    @State private var selectedMuteDuration: MuteDuration? = nil
    @StateObject private var viewModel: RoomListViewModel

    let roomModel: RoomModel
    @Binding var navPath: NavigationPath
    var onBack: () -> Void

    init(room: RoomModel,
         onBack: @escaping () -> Void,
         navPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navPath = navPath
        self.roomModel = room
        self.onBack = onBack
        let viewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            muteToggleSection
            muteDurationOptionsSection
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onChange(of: isMuted) { newValue in
            if !newValue {
                selectedMuteDuration = nil
                viewModel.unmuteRoomNotifications(for: roomModel) { _ in
                    if roomModel.isMuted {
                        viewModel.toggeleMuted(for: roomModel)
                        roomModel.isMuted = false
                    }
                }
            } else {
                // Call muteRoomNotifications method with selectedMuteDuration
                if let duration = selectedMuteDuration {
                    viewModel.muteRoomNotifications(for: roomModel, duration: duration) { _ in
                        if !roomModel.isMuted {
                            viewModel.toggeleMuted(for: roomModel)
                            roomModel.isMuted = true
                        }
                    }
                }
            }
        }.onAppear {
            roomModel.isMuted ? (isMuted = true) : (isMuted = false)
            roomModel.isMuted ? (selectedMuteDuration = .always) : nil
        }
    }

    var headerSection: some View {
        HStack {
            Button(action: {
                navPath.removeLast()
            }) {
                Image("back-long")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(.vertical, 10)
            }
            .padding(.leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }
            .padding(.leading, 4)
            
            Spacer()
        }.padding(.top, safeAreaTop() + 12)
    }

    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }

    var muteToggleSection: some View {
        HStack {
            Text("Mute")
                .font(.body)
                .foregroundColor(selectedMuteDuration == nil ? .gray : .black)
            
            Spacer()
            
            Toggle(isOn: $isMuted) {
                Text("")
            }
            .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
            .labelsHidden()
            .frame(width: 40)
            .disabled(selectedMuteDuration == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
    }

    var muteDurationOptionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration Options")
                .font(.subheadline)
                .foregroundColor(selectedMuteDuration == nil ? .gray : .black)
                .padding([.leading, .top], 20)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(MuteDuration.allCases, id: \.self) { option in
                    Button(action: {
                        selectedMuteDuration = option
                    }) {
                        HStack {
                            Image(systemName: selectedMuteDuration == option ? "circle.fill" : "circle")
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text("For \(option.label)")  // Display the label from MuteDuration
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.vertical, 6)
                    }
                    .foregroundColor(selectedMuteDuration == nil ? .gray : .black)
                }
            }.padding(.bottom, 20)
        }.background(Color.gray.opacity(0.1))
    }
}
