//
//  ProfileView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI
import SDWebImageSwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @Binding var navPath: NavigationPath

    @State private var isEditSheetPresented = false
    @StateObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var isEditingAbout = false
    @State private var editedAboutText = ""
    @State private var showEditSuccessAlert: Bool = false
    @State private var showFullScreen = false
    @State private var fullScreenUIImage: UIImage? = nil
    @State private var fileUploadRequest: FileUploadRequest?
    @StateObject private var chatViewModel: ChatViewModel
    @State private var imageDataToPass: (URL, String, String, Int)?
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    init(navPath: Binding<NavigationPath>) {
        _navPath = navPath
        let viewModel = DIContainer.shared.container.resolve(ProfileViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base Background
            VStack(spacing: UIConstants.NavBar.zeroSpacing) {
                Color(hex: "#0A171F")
                    .frame(height: UIConstants.Layout.ProfileView.topBackgroundHeight)
                    .edgesIgnoringSafeArea(.horizontal)
                Color(hex: "#202D35CC")
                    .edgesIgnoringSafeArea([.horizontal, .bottom])
            }
            .ignoresSafeArea()
            // MARK: Profile Contents
            VStack(spacing: UIConstants.NavBar.zeroSpacing) {
                Spacer(minLength: UIConstants.Layout.ProfileView.topBackgroundHeight / 3)
                // Profile image
                ZStack(alignment: .bottomTrailing) {
                    profileImageSection()
                    
                    Button(action: { isImagePickerPresented = true }) {
                        
                        Circle()
                            .frame(
                                width: UIConstants.Layout.ProfileView.CameraButton.size,
                                height: UIConstants.Layout.ProfileView.CameraButton.size
                            )
                            .overlay(
                                Image(.editCamera)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(
                                        width: UIConstants.Layout.ProfileView.CameraButton.size,
                                        height: UIConstants.Layout.ProfileView.CameraButton.size
                                    )
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth:                                     UIConstants.Layout.ProfileView.CameraButton.strokeWidth))
                            .shadow(radius: UIConstants.Layout.ProfileView.CameraButton.shadowRadius)
                            .offset(
                                x: -UIConstants.Layout.ProfileView.CameraButton.offset,
                                y: -UIConstants.Layout.ProfileView.CameraButton.offset
                            )
                    }
                }
                .padding(.top, UIConstants.Layout.ProfileView.ProfileImage.topPadding)
                .onAppear(perform: downloadProfileImage)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: UIConstants.Layout.ProfileView.scrollContentSpacing) {
                        aboutSection()
                            .padding(.horizontal, UIConstants.Layout.ProfileView.sectionHPadding)
                            .padding(.top, UIConstants.Layout.ProfileView.aboutTopPadding)
                        
                        VStack(spacing: UIConstants.Layout.ProfileView.fieldGroupSpacing) {
                            
                            profileField(icon: "edit_user", title: Constants.name.localized, value: viewModel.originalProfile?.name ?? "")
                            profileField(icon: "call_gray", title: Constants.mobile.localized, value: viewModel.originalProfile?.mobile ?? "")
                            profileField(icon: "mail", title: Constants.email.localized, value: viewModel.originalProfile?.email ?? "")
                            profileField(icon: "calender_icon", title: Constants.dob.localized, value: viewModel.originalProfile?.dob ?? "")
                            profileField(icon: "job", title:Constants.profession1.localized, value: viewModel.originalProfile?.profession ?? "")
                        }
                        .padding(.horizontal, UIConstants.Layout.ProfileView.sectionHPadding)
                        
                    }
                    .padding(.horizontal, UIConstants.Layout.ProfileView.sectionHPadding)
                    
                    Button(action: { isEditSheetPresented = true }) {
                        HStack {
                            Text(Constants.editProfile.localized)
                                .font(Design.Font.semiBold(14))
                                .foregroundColor(Design.Color.white)
                        }
                        .frame(
                            width: UIConstants.Layout.ProfileView.EditButton.width,
                            height: UIConstants.Layout.ProfileView.EditButton.height
                        )                        .padding()
                            .background(Design.Color.appGradient)
                            .cornerRadius(UIConstants.Layout.ProfileView.EditButton.cornerRadius)
                            .shadow(radius: UIConstants.Layout.ProfileView.EditButton.shadowRadius)
                    }
                    .padding(.horizontal, UIConstants.Layout.ProfileView.EditButton.hPadding)
                    .padding(.bottom, UIConstants.Layout.ProfileView.EditButton.bottomPadding)
                    .padding(.top, UIConstants.Layout.ProfileView.EditButton.topPadding)
                }
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: UIConstants.NavBar.zeroSpacing)
            }
            
            // MARK: Custom Back Button (Top Left)
            Button(action: {
                if !navPath.isEmpty {
                    navPath.removeLast()
                }
            }) {
                HStack(spacing: UIConstants.Layout.ProfileView.BackButton.hSpacing) {
                    Image(.chevronLeft)
                        .font(.system(
                            size: UIConstants.Layout.ProfileView.BackButton.iconSize,
                            weight: .semibold
                        ))
                        .foregroundColor(Design.Color.white)
                    
                    Text(Constants.profile.localized)
                        .font(Design.TextStyle.profileNavTitle)
                        .foregroundColor(Design.Color.white)
                }
                .padding(.vertical, UIConstants.Layout.verticalPadding)
            }
            .padding(.top, safeAreaTop() + UIConstants.Layout.ProfileView.backButtonTopOffset)
            .padding(.leading, UIConstants.Layout.ProfileView.backButtonLeading)
            .zIndex(2)
            
            // MARK: Alerts
            if showEditSuccessAlert, let alertModel = viewModel.alertModel {
                AlertView(model: alertModel) {
                    showEditSuccessAlert = false
                }
            }
        }
        // MARK: Sheets and Actions
        .sheet(isPresented: $isEditSheetPresented) {
            EditProfileView(viewModel: viewModel, showSuccessPopup: $showEditSuccessAlert)
                .presentationDetents([.large])
                .onDisappear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.downloadProfile()
                    }
                }
        }
        .onAppear {
            viewModel.loadProfile()
            downloadProfileImage()
            print("user name is 1234 : \( viewModel.originalProfile?.name ?? "") ")

        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker { url, fileName, mimeType, filesize in
                if let url = url,
                   let imageData = try? Data(contentsOf: url),
                   let image = UIImage(data: imageData) {
                    fileUploadRequest = FileUploadRequest(file: imageData, filename: fileName ?? "", mimeType: mimeType ?? "")
                    selectedImage = image
                    imageDataToPass = (url, fileName ?? "", mimeType ?? "", filesize ?? 0)
                }
            }
            .onChange(of: selectedImage) { _ in uploadProfileImage() }
        }.onChange(of: viewModel.originalProfile?.profileImageUrl) { newUrl in
            if let newUrl, !newUrl.isEmpty {
                downloadProfileImage()
            }
        }
    }
    // MARK: - Header Section
    @ViewBuilder
    private func headerSection() -> some View {
        HStack(spacing: UIConstants.Layout.internalPadding) {
            Button(action: {
                if !navPath.isEmpty {
                    navPath.removeLast()
                }
            }) {
                HStack(spacing: UIConstants.Layout.ProfileView.BackButton.hSpacing) {
                    Image(.chevronLeft)
                        .font(.system(
                            size: UIConstants.Layout.ProfileView.BackButton.iconSize,
                            weight: .semibold
                        ))
                    Text(Constants.profile.localized)
                        .font(Design.TextStyle.profileNavTitleLg)
                }
                .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, UIConstants.Layout.ProfileView.sectionHPadding)
        .padding(.bottom, UIConstants.Layout.smallBottomPadding)
    }
    // MARK: - Helpers

    private func downloadProfileImage() {
        guard let profileMxcUrl = viewModel.originalProfile?.profileImageUrl,
              !profileMxcUrl.isEmpty else { return }
        MediaCacheManager.shared.getMedia(
            url: profileMxcUrl,
            type: .image,
            progressHandler: { progress in
                downloadProgress = progress
            },
            completion: { result in
                switch result {
                case .success(let pathString):
                    // Build a safe file URL from either "file://…" or raw path
                    let localURL: URL = {
                        if let u = URL(string: pathString), u.scheme == "file" { return u }
                        return URL(fileURLWithPath: pathString)
                    }()
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            do {
                                // 1) Exists & not a directory
                                var isDir: ObjCBool = false
                                guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDir),
                                      !isDir.boolValue else {
                                    throw NSError(domain: "Media", code: 8201,
                                                  userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                }
                                
                                // 2) Type-gate: only decode images
                                if let ut = UTType(filenameExtension: localURL.pathExtension),
                                   !ut.conforms(to: .image) {
                                    throw NSError(domain: "Media", code: 8202,
                                                  userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                }
                                
                                // 3) Downsample via ImageIO (low memory)
                                let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                var ui: UIImage? = nil
                                if let src = CGImageSourceCreateWithURL(localURL as CFURL, srcOpts as CFDictionary) {
                                    let opts: [CFString: Any] = [
                                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceShouldCacheImmediately: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 2048 // adjust if needed
                                    ]
                                    if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                        ui = UIImage(cgImage: cg)
                                    }
                                }
                                
                                // 4) Fallbacks
                                if ui == nil { ui = UIImage(contentsOfFile: localURL.path) }
                                if ui == nil {
                                    let data = try Data(contentsOf: localURL, options: [.mappedIfSafe])
                                    ui = UIImage(data: data)
                                }
                                guard var img = ui else {
                                    throw NSError(domain: "Media", code: 8203,
                                                  userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                }
                                
                                if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                
                                DispatchQueue.main.async {
                                    downloadedImage = img
                                    fullScreenUIImage = img
                                }
                                
                            } catch {
                                print("Media decode error — \(error.localizedDescription) | \(localURL.path)")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("Failed to download media: \(error)")
                }
            }
        )
    }
    
    private func uploadProfileImage() {
        LoaderManager.shared.show()
        guard let imageDataToPass = imageDataToPass else { return }
        chatViewModel.uploadUserProfile(fileURL: imageDataToPass.0,
                                        fileName: imageDataToPass.1,
                                        mimeType: imageDataToPass.2) { success, mediaURL in
            print("mediaURLmediaURL", mediaURL)
            LoaderManager.shared.hide()
            guard success, let mediaURL = mediaURL else {
                self.viewModel.showAlertForDeniedPermission(success: success)
                showEditSuccessAlert = true
                return
            }
            viewModel.editableProfile?.profileImageUrl = "\(mediaURL)"
            viewModel.updateProfileIfNeeded { success in
                if !success {
                    self.viewModel.showAlertForDeniedPermission(success: success)
                    showEditSuccessAlert = true
                }
            }
        }
    }

    @ViewBuilder
    private func profileImageSection() -> some View {
        if let selectedImage = selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIConstants.Layout.ProfileView.ProfileImage.size,
                    height: UIConstants.Layout.ProfileView.ProfileImage.size
                )
                .clipShape(Circle())
                .shadow(radius: UIConstants.Layout.ProfileView.ProfileImage.shadowRadius)
            
                .onTapGesture { showFullScreen = true }
                .fullScreenCover(isPresented: $showFullScreen) {
                    FullScreenImageView(
                        source: .uiImage(selectedImage),
                        userName: viewModel.originalProfile?.name ?? "",
                        timeText: "",
                        isPresented: $showFullScreen
                    )
                }
        } else if let image = downloadedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIConstants.Layout.ProfileView.ProfileImage.size,
                    height: UIConstants.Layout.ProfileView.ProfileImage.size
                )
                .clipShape(Circle())
                .shadow(radius: UIConstants.Layout.ProfileView.ProfileImage.shadowRadius)
            
                .onTapGesture {
                    fullScreenUIImage = downloadedImage
                    showFullScreen = true
                }
                .fullScreenCover(isPresented: $showFullScreen) {
                    if let fullScreenUIImage = self.fullScreenUIImage {
                        FullScreenImageView(
                            source: .uiImage(fullScreenUIImage),
                            userName: viewModel.originalProfile?.name ?? "",
                            timeText: "",
                            isPresented: $showFullScreen
                        )
                    }
                }
        } else {
            Image(.profileIcon)
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIConstants.Layout.ProfileView.ProfileImage.size,
                    height: UIConstants.Layout.ProfileView.ProfileImage.size
                )
                .clipShape(Circle())
                .shadow(radius: UIConstants.Layout.ProfileView.ProfileImage.shadowRadius)
        }
    }
    
    @ViewBuilder
    private func profileField(icon: String, title: String, value: String) -> some View {
        HStack(spacing: UIConstants.Layout.ProfileView.ProfileField.hSpacing) {
            // Icon
            ZStack {
                Image( icon)
                    .font(.system(size: UIConstants.Layout.ProfileView.ProfileField.iconSize))
                    .foregroundColor(.white.opacity(UIConstants.Layout.ProfileView.iconOpacity))
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: UIConstants.Layout.ProfileView.ProfileField.textSpacing) {
                
                Text(value.isEmpty ? Constants.notSet.localized : value)
                    .font(Design.TextStyle.profileFieldValue)
                    .foregroundColor(
                        value.isEmpty
                        ? .white.opacity(UIConstants.Layout.ProfileView.ProfileField.emptyOpacity)
                        : .white
                    )
                Text(title)
                    .font(Design.TextStyle.profileFieldTitle)
                    .foregroundColor(.white.opacity(UIConstants.Layout.ProfileView.subtitleOpacity))
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func aboutSection() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: UIConstants.Layout.ProfileView.AboutSection.textSpacing) {
                Text(Constants.about.localized)
                    .font(Design.TextStyle.profileAboutLabel)
                    .foregroundColor(Design.Color.white.opacity(UIConstants.Layout.ProfileView.AboutSection.labelOpacity))
                
                if let about = viewModel.originalProfile?.about, !about.isEmpty {
                    Text(about)
                        .font(Design.TextStyle.profileAboutText)
                        .foregroundColor(Design.Color.white)
                } else {
                    Text("")
                }
            }
            Spacer()
            Button {
                editedAboutText = viewModel.editableProfile?.about ?? ""
                isEditingAbout = true
            } label: {
            }
        }
        .padding(.horizontal, UIConstants.Layout.ProfileView.AboutSection.hPadding)
        .sheet(isPresented: $isEditingAbout, onDismiss: {
            viewModel.editableProfile?.about = editedAboutText
            viewModel.updateProfileIfNeeded { success in
                hideKeyboard()
                self.viewModel.showAlertForDeniedPermission(success: success)
                showEditSuccessAlert = true
            }
        }) {
            NavigationView {
                VStack {
                    TextEditor(text: $editedAboutText)
                        .padding()
                        .frame(height: UIConstants.Layout.ProfileView.AboutSection.editorHeight)
                        .background(
                            Design.Color.white.opacity(UIConstants.Layout.ProfileView.AboutSection.editorOpacity)
                        )
                        .foregroundColor(
                            Design.Color.black.opacity(UIConstants.Layout.ProfileView.AboutSection.editorOpacity)
                        )
                        .scrollContentBackground(.hidden)
                        .cornerRadius(UIConstants.Layout.ProfileView.AboutSection.cornerRadius)
                        .padding()
                    Spacer()
                }
                .background(Design.Color.white)
                .navigationTitle(Constants.editAbout.localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Constants.cancel.localized) { isEditingAbout = false }
                            .foregroundColor(Design.Color.navy)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Constants.save.localized) { isEditingAbout = false }
                            .foregroundColor(Design.Color.navy)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Safe Area Helper
private func safeAreaTop() -> CGFloat {
    UIApplication.shared.topSafeAreaInset
}
