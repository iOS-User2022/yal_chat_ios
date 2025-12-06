//
//  ContactRowView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//


import SwiftUI

struct ContactRowView: View {
    let contact: ContactLite

    var body: some View {
        HStack(spacing: 12) {
            if let imageURLString = contact.avatarURL {
                MediaView(
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
                MediaView(
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
                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
                    .frame(width: 40, height: 40)  // Set the circle size
                    .background(contact.randomeProfileColor.opacity(0.3))
                    .clipShape(Circle())
            }

            Text(contact.fullName ?? "")
                .font(Design.Font.bold(14))
                .foregroundColor(Design.Color.primaryText)

            Spacer()
        }
        .padding(.vertical, 2)
        .background(Design.Color.clear)
    }
    
    private var placeholderInitialsView: some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(8))
            .frame(width: 40, height: 40)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryText.opacity(0.7))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Design.Color.white, lineWidth: 1)
            )
    }
}
