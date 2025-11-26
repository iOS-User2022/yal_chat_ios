//
//  TypingIndicatorView.swift
//  YAL
//
//  Created by Vishal Bhadade on 07/06/25.
//


import SwiftUI

struct TypingIndicatorView: View {
    let typingUsers: [ContactModel] // at least 1 user
    let isGroup: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isGroup {
                HStack(spacing: -10) {
                    ForEach(typingUsers.prefix(3), id: \.userId) { user in
                        avatarView(for: user)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 2) {
                Text("Typing")
                    .font(Design.Font.regular(10))
                    .italic()
                    .foregroundColor(Design.Color.primaryText)

                TypingDotsView()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(bubbleBackground)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

            Spacer()
        }
    }

    private func avatarView(for user: ContactModel) -> some View {
        ZStack {
            if let url = user.avatarURL {
                AsyncImage(url: URL(string: url)) { phase in
                    if let image = phase.image {
                        image.resizable()
                    } else {
                        Color.gray
                    }
                }
            } else {
                Circle()
                    .fill(user.randomeProfileColor)
                    .overlay(Text(getInitials(from: user.fullName ?? user.phoneNumber)).font(.caption).foregroundColor(.white))
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 1))
    }
    
    // MARK: - Background
    private var bubbleBackground: some View {
        CustomRoundedCornersShape(
            radius: 8,
            roundedCorners: [.topRight, .bottomLeft, .bottomRight]
        )
        .fill(Design.Color.white)
    }
}

// MARK: - Typing Dots View

struct TypingDotsView: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Design.Color.appGradient)
                    .frame(width: 2, height: 2)
                    .offset(y: bounce ? -6 : 0) // Move only downward
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: bounce
                    )
            }
        }
        .onAppear {
            bounce = true
        }
    }
}
