//
//  ContactRowView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//


import SwiftUI

struct ContactRowView: View {

        let contact: ContactLite
        var onProfileTap: (() -> Void)? = nil

        var body: some View {
            Button(action: {
                onProfileTap?()
            }) {
                HStack(spacing: 12) {
                    // Profile Image
                    if let imageURLString = contact.avatarURL {
                        NonInteractiveMediaView(
                            mediaURL: imageURLString,
                            userName: "",
                            timeText: "",
                            mediaType: .image,
                            placeholder: placeholderInitialsView,
                            errorView: placeholderInitialsView,
                            isSender: false,
                            downloadedImage: nil,
                            senderImage: "",
                            localURLOverride: nil
                        )
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else if let imageURLString = contact.imageURL {
                        NonInteractiveMediaView(
                            mediaURL: imageURLString,
                            userName: "",
                            timeText: "",
                            mediaType: .image,
                            placeholder: placeholderInitialsView,
                            errorView: placeholderInitialsView,
                            isSender: false,
                            downloadedImage: nil,
                            senderImage: "",
                            localURLOverride: nil
                        )
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        // Generate a placeholder with initials
                        Text(getInitials(from: contact.fullName ?? ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                            .frame(width: 40, height: 40)
                            .background(contact.randomeProfileColor.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Text(contact.fullName ?? "")
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.primaryTextColor)
                    
                    Spacer()
                }
                .padding(.vertical, 2)
                .background(Design.Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private var placeholderInitialsView: some View {
            return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
                .font(Design.Font.bold(8))
                .frame(width: 40, height: 40)
                .background(randomBackgroundColor())
                .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Design.Color.white, lineWidth: 1)
                )
        }
    }

    // MARK: - Non-Interactive MediaView Wrapper
    struct NonInteractiveMediaView<Placeholder: View, ErrorView: View>: View {
        let mediaURL: String
        let userName: String?
        let timeText: String?
        let mediaType: MediaType
        let placeholder: Placeholder
        let errorView: ErrorView
        let isSender: Bool
        let downloadedImage: UIImage?
        let senderImage: String
        var localURLOverride: URL? = nil
        
        @StateObject private var loader = MediaLoader()
        @State private var isVisible = false
        
        var body: some View {
            ZStack {
                if let img = loader.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        // No tap gesture here - let parent handle navigation
                } else if loader.progress > 0 && loader.progress < 1 {
                    placeholder
                } else if loader.error != nil {
                    errorView
                } else {
                    placeholder
                }
            }
            .onAppear {
                isVisible = true
                loader.isVisible = true
                
                if let local = localURLOverride {
                    loader.load(remoteURL: "", type: mediaType, localURL: local)
                } else if !mediaURL.isEmpty {
                    // Check cache first
                    MediaCacheManager.shared.peekCachedPath(url: mediaURL) { cachedPath in
                        guard isVisible else { return }
                        
                        if let cachedPath, !cachedPath.isEmpty {
                            let url = cachedPath.hasPrefix("file://")
                                ? URL(string: cachedPath)!
                                : URL(fileURLWithPath: cachedPath)
                            
                            loader.load(remoteURL: "", type: mediaType, localURL: url)
                        } else {
                            // Load from network
                            loader.load(remoteURL: mediaURL, type: mediaType, localURL: nil)
                        }
                    }
                }
            }
            .onDisappear {
                isVisible = false
                loader.isVisible = false
            }
        }
    }
