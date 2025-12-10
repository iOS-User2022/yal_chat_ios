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
            VStack(spacing: 0) {
                Color.white
                    .frame(height: 226)
                    .edgesIgnoringSafeArea(.horizontal)
                Design.Color.appGradient
                    .edgesIgnoringSafeArea([.horizontal, .bottom])
            }
            
            // MARK: Profile Contents
            VStack(spacing: 0) {
                Spacer(minLength: 80)
                
                // Profile image
                ZStack(alignment: .bottomTrailing) {
                    profileImageSection()
                    
                    Button(action: { isImagePickerPresented = true }) {
                        Circle()
                            .fill(Design.Color.appGradient)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image("edit-light")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                            .offset(x: -6, y: -6)
                    }
                }
                .padding(.top, 80)
                .onAppear(perform: downloadProfileImage)
                
                ScrollView {
                    VStack(spacing: 24) {
                        aboutSection()
                        profileField(icon: "user-light", title: "Name", value: viewModel.originalProfile?.name ?? "")
                        profileField(icon: "call-light", title: "Mobile", value: viewModel.originalProfile?.mobile ?? "")
                        profileField(icon: "sms-light", title: "Email", value: viewModel.originalProfile?.email ?? "")
                        profileField(icon: "calendar-light", title: "D.O.B.", value: viewModel.originalProfile?.dob ?? "")
                        profileField(icon: "briefcase-light", title: "Profession", value: viewModel.originalProfile?.profession ?? "")
                        
                        Button(action: { isEditSheetPresented = true }) {
                            HStack {
                                Image("edit")
                                Spacer().frame(width: 8)
                                Text("Edit Profile")
                                    .font(Design.Font.regular(14))
                                    .foregroundColor(Design.Color.headingText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Design.Color.lightGrayBackground)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 20)
                }
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }

            // MARK: Custom Back Button (Top Left)
            Button(action: {
                if !navPath.isEmpty {
                    navPath.removeLast()
                }
            }) {
                HStack(spacing: 10) {
                    Image("back")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text("Profile")
                        .font(Design.Font.bold(16))
                        .foregroundColor(Design.Color.primaryText)
                }
                .padding(.vertical, 10)
            }
            .padding(.top, safeAreaTop() + 10)
            .padding(.leading, 10)
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
                                print("❌ Media decode error — \(error.localizedDescription) | \(localURL.path)")
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to download media: \(error)")
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
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 6)
                .onTapGesture { showFullScreen = true }
                .fullScreenCover(isPresented: $showFullScreen) {
                    FullScreenImageView(
                        source: .uiImage(selectedImage),
                        userName: "",
                        timeText: "",
                        isPresented: $showFullScreen
                    )
                }
        } else if let image = downloadedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 6)
                .onTapGesture {
                    fullScreenUIImage = downloadedImage
                    showFullScreen = true
                }
                .fullScreenCover(isPresented: $showFullScreen) {
                    if let fullScreenUIImage = self.fullScreenUIImage {
                        FullScreenImageView(
                            source: .uiImage(fullScreenUIImage),
                            userName: "",
                            timeText: "",
                            isPresented: $showFullScreen
                        )
                    }
                }
        } else {
            Image("profile-icon")
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 6)
        }
    }

    @ViewBuilder
    private func profileField(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(icon)
                .scaledToFit()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.white.opacity(0.6))
                Text(value)
                    .font(Design.Font.bold(14))
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func aboutSection() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("About")
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.white.opacity(0.6))
                
                if let about = viewModel.originalProfile?.about, !about.isEmpty {
                    Text(about)
                        .font(Design.Font.regular(12))
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
                Image("edit-light")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
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
                        .frame(height: 200)
                        .background(Design.Color.white.opacity(0.7))
                        .foregroundColor(Design.Color.black.opacity(0.7))
                        .scrollContentBackground(.hidden)
                        .cornerRadius(8)
                        .padding()
                    Spacer()
                }
                .background(Design.Color.white)
                .navigationTitle("Edit About")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isEditingAbout = false }
                            .foregroundColor(Design.Color.navy)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { isEditingAbout = false }
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
