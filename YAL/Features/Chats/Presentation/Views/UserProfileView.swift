//
//  UserProfileView.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/06/25.
//


import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

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
    @StateObject private var chatViewModel: ChatViewModel
    @State private var navigateToCallScreen = false
    @EnvironmentObject var callManager: CallManager
    
    @State private var showBlock = false
    @State private var showUnBlock = false
    @State private var showDelete = false
    @State private var showCopiedToast = false
    @State private var showClearChat = false
    @State private var showClearChatSucccussToast: Bool = false

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
        
        let chatVM = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: chatVM)
        
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
                
                if showClearChat {
                    ClearChatView(
                        onClear: {
                            onClearChat()
                            showClearChat = false
                            viewModel.showAlertForSuccess()
                            showClearChatSucccussToast = true
                        },
                        onCancel: { showClearChat = false }
                    )
                }
                if showClearChatSucccussToast, let alertModel = viewModel.alertModel {
                    AlertView(model: alertModel) {
                        showClearChatSucccussToast = false
                    }
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
                UserImageView(url: roomModel.opponent?.avatarURL, size: 100, roomModel: roomModel)
                Spacer().frame(height: 8)
                
                let user = viewModel.userDetails
                
                let nameToShow: String? = {
                    if let fullName = user?.fullName, !fullName.isEmpty {
                        return fullName
                    }
                    if let displayName = user?.displayName, !displayName.isEmpty {
                        return displayName
                    }
                    
                    return nil
                }()
                
                if let displayName = nameToShow {
                    Text(displayName)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(height: 4)
                }

                if let phoneNumber = viewModel.userDetails?.phoneNumber {
                    Text(phoneNumber)
                        .font(.callout)
                        .foregroundColor(showCopiedToast ? .blue : .gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onLongPressGesture {
                            UIPasteboard.general.string = phoneNumber
                            HapticFeedback.success()
                            
                            withAnimation {
                                showCopiedToast = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        }
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
                    var eventId = UUID().uuidString
                    
                    Button {
                        chatViewModel.currentRoomId = roomModel.id
                        chatViewModel.sendCallMessage(
                            callState: .outgoing,
                            isVideo: false,
                            eventId: eventId
                        ) { result in
                            switch result {
                                case .success(let newEventId):
                                    print("Message sent successfully: \(newEventId)")
                                    eventId = newEventId
                                    CallManager.shared.eventId = newEventId
                                    CallManager.shared.updateCallStatus()

                                    //chatViewModel.becomeActiveCallMessageHandler(eventID: newEventId)
                                case .failure(let error):
                                    print("Failed to send call message:", error.localizedDescription)
                            }
                        }
                        CallManager.shared.presentCall(for: roomModel)
                        CallManager.shared.isVideoCall = false
//                        $navPath.wrappedValue.append(NavigationTarget.callManager(room: roomModel, autoAccept: false))
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
                                    print("Message sent successfully: \(newEventId)")
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
//                        $navPath.wrappedValue.append(NavigationTarget.callManager(room: roomModel, autoAccept: false))
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
        .background(Design.Color.backgroundColor)
        .overlay(alignment: .top) {
            if showCopiedToast {
                ToastView(message: "Copied!")
                    .padding(.top, 60)
            }
        }
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.userDetails?.statusMessage ?? "No about info available")
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
        onBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(
                name: .deepLinkScrollToMessage,
                object: nil,
                userInfo: ["messageId": messageId]
            )
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
                            if let u = URL(string: imagePath), u.scheme == "file" { return u }
                            return URL(fileURLWithPath: imagePath)
                        }()
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            autoreleasepool {
                                do {
                                    // 1) Exists & not a directory
                                    var isDir: ObjCBool = false
                                    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                          !isDir.boolValue else {
                                        throw NSError(domain: "ImageOverlayView", code: 7101,
                                                      userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                    }
                                    
                                    // 2) Type-gate: only decode images
                                    if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                       !ut.conforms(to: .image) {
                                        throw NSError(domain: "ImageOverlayView", code: 7102,
                                                      userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                    }
                                    
                                    // 3) Downsample with ImageIO (low memory)
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
                                        throw NSError(domain: "ImageOverlayView", code: 7103,
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

    var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.sharedGroups.count) Group\(viewModel.sharedGroups.count == 1 ? "" : "s") in common")
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.primaryTextColor)
            
            ForEach(viewModel.sharedGroups.prefix(3), id: \.id) { group in
                HStack(spacing: 12) {
                    UserImageView(url: group.avatarUrl, size: 40, roomModel: group).disabled(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.primaryTextColor)
                        Text(group.participants.map { $0.firstNameOrFallback }.joined(separator: ", "))
                            .font(Design.Font.regular(12))
                            .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
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
                            .foregroundColor(Design.Color.primaryTextColor)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(Design.Color.darkgrayColor))
        .cornerRadius(10)
    }

    var actionsSection: some View {
        VStack(spacing: 0) {
            
            Button(action: {
                $navPath.wrappedValue.append(NavigationTarget.notificationSettings(room: roomModel))
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image(roomModel.isMuted ? "notification-unmute" : "notification-mute")
                        .renderingMode(.template)
                        .resizable()
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
                viewModel.toggeleFavorite(for: roomModel)
            }) {
                HStack(alignment: .bottom, spacing: 12) {
                    Image(viewModel.isFavorite ? "un-favorite" : "favorite")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                    Text(viewModel.isFavorite ? "Remove from favorites" : "Add to favorites")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                    Spacer()
                }
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
            if roomModel.isBlocked {
                       Button(action: {
                           showUnBlock = true
                       }) {
                           HStack(alignment: .bottom, spacing: 12) {
                               Image("shield-cross-blue")
                                   .frame(width: 16, height: 16)
                               Text("Unblock")
                                   .font(Design.Font.regular(14))
                                   .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
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
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Design.Color.destructiveRed, lineWidth: 1)
            )
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
                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
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
                        // Build a safe file URL from either "file://…" or raw path
                        let fileURL: URL = {
                            if let u = URL(string: imagePath), u.scheme == "file" { return u }
                            return URL(fileURLWithPath: imagePath)
                        }()
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            autoreleasepool {
                                do {
                                    // 1) Exists & not a directory
                                    var isDir: ObjCBool = false
                                    guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                          !isDir.boolValue else {
                                        throw NSError(domain: "ChatHeaderView", code: 5201,
                                                      userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                    }
                                    
                                    // 2) Type-gate: only decode images
                                    if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                       !ut.conforms(to: .image) {
                                        throw NSError(domain: "ChatHeaderView", code: 5202,
                                                      userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                    }
                                    
                                    // 3) Downsample with ImageIO (low memory)
                                    let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                    var ui: UIImage? = nil
                                    if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                        let opts: [CFString: Any] = [
                                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceShouldCacheImmediately: true,
                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 1536 // tweak if needed
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
                                        throw NSError(domain: "ChatHeaderView", code: 5203,
                                                      userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                    }
                                    
                                    if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                    
                                    DispatchQueue.main.async { downloadedImage = img }
                                    
                                } catch {
                                    print("ChatHeaderView: image decode error — \(error.localizedDescription) | \(fileURL.path)")
                                }
                            }
                        }
                        
                    case .failure(let error):
                        print("ChatHeaderView: failed to load image — \(error)")
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
                    .foregroundColor(Design.Color.primaryTextColor)
            }
            .padding(.leading, 4)
            
            Spacer()
        }.padding(.top, safeAreaTop() + 12)
    }

    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }

    var muteToggleSection: some View {
        HStack {
            Text("Mute")
                .font(.body)
                .foregroundColor(!isMuted ? .gray : .white)
            
            Spacer()
            
            Toggle(isOn: $isMuted) {
                Text("")
            }
            .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
            .labelsHidden()
            .frame(width: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(Design.Color.darkgrayColor))
        )
        .padding(.horizontal)
    }

    var muteDurationOptionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration Options")
                .font(.subheadline)
                .foregroundColor(!isMuted ? .gray : .white)
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
                    .foregroundColor(!isMuted ? .gray : .white)
                }
            }.padding(.bottom, 20)
        }.background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(Design.Color.darkgrayColor))
        )
        .padding(.horizontal)
    }
}
struct HapticFeedback {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
struct ToastView: View {
    var message: String
    
    var body: some View {
        Text(message)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.25), value: message)
    }
}
