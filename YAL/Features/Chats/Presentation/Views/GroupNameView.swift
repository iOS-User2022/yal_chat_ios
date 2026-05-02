//
//  GroupNameScreen.swift
//  YAL
//
//  Created by Vishal Bhadade on 22/05/25.
//


import SwiftUI
import SDWebImageSwiftUI

struct GroupNameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var groupName: String = ""
    @State private var displayImage: String = ""
    @Binding var selectedContacts: [ContactLite]
    @State private var isImagePickerPresented = false
    @State private var selectedImage: UIImage?
    @StateObject private var chatViewModel: ChatViewModel
    
    var onCreateGroup: ((String, String, [ContactLite]) -> Void)?
    var onDismiss: (() -> Void)?
    
    init(
        selectedContacts: Binding<[ContactLite]>,
        onCreateGroup: ((String, String, [ContactLite]) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: vm)
        
        // Default values
        self._selectedContacts = selectedContacts
        self.onCreateGroup = onCreateGroup
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text("New group")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 40)
                
                // Centered Group Avatar
                VStack(spacing: 16) {
                    Button(action: {
                        isImagePickerPresented = true
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            // Avatar circle
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                            } else if !displayImage.isEmpty, let profileImageUrl = URL(string: displayImage) {
                                WebImage(url: profileImageUrl, options: [.retryFailed, .continueInBackground]) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                    } else {
                                        placeholderAvatarView()
                                    }
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                            } else {
                                placeholderAvatarView()
                            }
                            
                            // Edit icon overlay
                            Circle()
                                .fill(Color(red: 0.2, green: 0.5, blue: 1.0))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image("edit_icon")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 4, y: 4)
                        }
                    }
                    
                    // Group Name TextField
                    TextField("", text: $groupName)
                        .placeholder(when: groupName.isEmpty) {
                            Text("Enter group name")
                                .foregroundColor(.white.opacity(0.4))
                                .font(.system(size: 16))
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                
                // Members Section - Updated to Horizontal Layout
                VStack(alignment: .leading, spacing: 16) {
                    Text("Member : \(selectedContacts.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    // Horizontal ScrollView for members
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(selectedContacts) { contact in
                                VStack(spacing: 16) {
                                    ZStack(alignment: .topTrailing) {
                                        // Avatar
                                        Group {
                                            if let imageURLString = contact.avatarURL {
                                                MediaView(
                                                    mediaURL: imageURLString,
                                                    userName: "",
                                                    timeText: "",
                                                    mediaType: .image,
                                                    placeholder: placeholderInitialsView(for: contact),
                                                    errorView: placeholderInitialsView(for: contact),
                                                    isSender: false,
                                                    downloadedImage: nil,
                                                    senderImage: "",
                                                    localURLOverride: nil
                                                )
                                                .scaledToFill()
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                            } else if let imageURLString = contact.imageURL {
                                                MediaView(
                                                    mediaURL: imageURLString,
                                                    userName: "",
                                                    timeText: "",
                                                    mediaType: .image,
                                                    placeholder: placeholderInitialsView(for: contact),
                                                    errorView: placeholderInitialsView(for: contact),
                                                    isSender: false,
                                                    downloadedImage: nil,
                                                    senderImage: "",
                                                    localURLOverride: nil
                                                )
                                                .scaledToFill()
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                            } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 48, height: 48)
                                                    .clipShape(Circle())
                                            } else {
                                                Text(getInitials(from: contact.fullName ?? ""))
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 48, height: 48)
                                                    .background(contact.randomeProfileColor.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        
                                        // Remove button
                                        Button(action: {
                                            if let idx = selectedContacts.firstIndex(of: contact) {
                                                selectedContacts.remove(at: idx)
                                            }
                                        }) {
                                            Circle()
                                                .fill(Color(red: 0.2, green: 0.5, blue: 1.0))
                                                .frame(width: 22, height: 22)
                                                .overlay(
                                                    Image("x-small")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                                .offset(x: 1, y: -1)
                                        }
                                    }
                                    
                                    Text(contact.fullName?.components(separatedBy: " ").first ?? "")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                        .frame(maxWidth: 56)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 30)
                
                Spacer()
                
                // Bottom Action Buttons Container
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: {
                            onDismiss?()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                        }
                        
                        Button(action: {
                            onCreateGroup?(groupName, displayImage, selectedContacts)
                        }) {
                            Text("Create Group")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.3, green: 0.4, blue: 1.0),
                                                    Color(red: 0.55, green: 0.36, blue: 0.96)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .opacity(groupName.isEmpty || selectedContacts.isEmpty ? 0.5 : 1.0)
                                )
                        }
                        .disabled(groupName.isEmpty || selectedContacts.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(Design.Color.darkgrayColor))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -4)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .background(Design.Color.backgroundColor)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker { url, fileName, mimeType, filesize  in
                if let url = url,
                   let imageData = try? Data(contentsOf: url),
                   let image = UIImage(data: imageData) {
                    selectedImage = image
                }
                if let url = url, let fileName = fileName, let mimeType = mimeType {
                    chatViewModel.uploadGroupProfile(
                        fileURL: url,
                        fileName: fileName,
                        mimeType: mimeType
                    ) { uploadedUrl in
                        displayImage = uploadedUrl?.absoluteString ?? ""
                        print("url uploadedUrl", uploadedUrl?.absoluteString ?? "")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func placeholderAvatarView() -> some View {
        // Group icon from assets folder with circular shape
        Image("group_icon")
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipShape(Circle())
    }
    
    private func placeholderInitialsView(for contact: ContactLite) -> some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(.system(size: 20, weight: .bold))
            .frame(width: 60, height: 60)
            .background(randomBackgroundColor())
            .foregroundColor(.white)
            .clipShape(Circle())
    }
}

// MARK: - TextField Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
