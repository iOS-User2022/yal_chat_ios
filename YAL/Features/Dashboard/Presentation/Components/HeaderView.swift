//
//  HeaderView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI

struct HeaderView: View {
    var onMenuTap: () -> Void = {}
    var onProfileTap: () -> Void = {}
    @State private var imageUrl: URL? = nil

    var body: some View {
        VStack {
            HStack {
                MenuButton(onTap: onMenuTap)
                Spacer()
                HeaderLogo()
                Spacer()
                ProfileImageView(imageUrl: imageUrl, onTap: onProfileTap)
            }
            .padding(.horizontal)
            .padding(.top, safeAreaTop()) // 👈 dynamically adjusts for notch
            .padding(.bottom, 8)
            .background(Color.white)
        }
        .onAppear {
            loadProfileImage()
        }
    }

    private func loadProfileImage() {
        if let profile = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let imageUrlString = profile.profileImageUrl,
           let url = URL(string: imageUrlString) {
            imageUrl = url
        }
    }

    /// Detects safe area inset (status bar height)
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }
}
