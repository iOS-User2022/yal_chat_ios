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
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image("back-long")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                Text("New group")
                    .font(Design.Font.bold(16))
                    .foregroundColor(Design.Color.primaryText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 30)

            
            // Group Avatar & Name Field
            HStack(spacing: 12) {
                // Placeholder for group avatar (optionally add tap action to pick an image)
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        if let selectedImage = selectedImage {
                            // If a new image was selected from gallery
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                        } else if let profileImageUrl = URL(string: "") {
                            WebImage(url: profileImageUrl, options: [.retryFailed, .continueInBackground]) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                } else {
                                    Image(systemName: "camera")
                                        .font(.system(size: 22))
                                        .foregroundColor(.gray)
                                }
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                        } else {
                            // No URL, no new image → fallback placeholder
                            Image(systemName: "camera")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                TextField(
                    "",
                    text: $groupName,
                    prompt: Text("Enter group name")
                        .foregroundColor(Design.Color.secondaryText.opacity(0.7))
                        .font(Design.Font.body)
                )
                .font(Design.Font.body)
                .multilineTextAlignment(.center)
                .padding(12)
                .overlay(
                    Rectangle()
                        .fill(Design.Color.navy)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            separatorView()
            
            // Members row
            VStack(alignment: .leading, spacing: 8) {
                Text("Member : \(selectedContacts.count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(selectedContacts) { contact in
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    // Avatar
                                    if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Text(getInitials(from: contact.fullName ?? ""))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Design.Color.primaryText.opacity(0.7))
                                            .frame(width: 40, height: 40)  // Set the circle size
                                            .background(contact.randomeProfileColor.opacity(0.3))
                                            .clipShape(Circle())
                                    }
                                    // Remove button
                                    Button(action: {
                                        if let idx = selectedContacts.firstIndex(of: contact) {
                                            selectedContacts.remove(at: idx)
                                        }
                                    }) {
                                        Image("cross-circle")
                                            .resizable()
                                            .background(Circle().fill(Design.Color.white))
                                            .clipShape(Circle())
                                            .frame(width: 22, height: 22)
                                            .offset(x: 10, y: 20)
                                    }
                                }
                                
                                Text(contact.fullName ?? "")
                                    .font(Design.Font.semiBold(10))
                                    .foregroundColor(Design.Color.primaryText)
                                    .frame(maxWidth: 52)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            
            Spacer()
            
            // Bottom bar
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Button("Cancel") {
                        onDismiss?()
                    }
                    .font(Design.Font.regular(14))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Design.Color.lightWhiteBackground)
                    .cornerRadius(8)
                    .foregroundColor(Design.Color.primaryText)
                    
                    Button("Create Group") {
                        onCreateGroup?(groupName, displayImage, selectedContacts)
                    }
                    .disabled(groupName.isEmpty || selectedContacts.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (groupName.isEmpty || selectedContacts.isEmpty)
                        ? Design.Color.appGradient.opacity(0.6)
                        : Design.Color.appGradient.opacity(1.0)
                    )
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .padding(.top, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial) // Native blurred background
                    .background(Color.white.opacity(0.6)) // Light white tint
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -4)
            )
        }
        .background(Color.white.ignoresSafeArea())
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
    
    @ViewBuilder
    private func separatorView() -> some View {
        Rectangle()
            .fill(Design.Color.appGradient.opacity(0.12))
            .frame(height: 8)

    }
}
