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
            if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
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
}
