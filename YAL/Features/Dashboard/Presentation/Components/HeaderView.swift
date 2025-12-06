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
    @ObservedObject var profileViewModel: ProfileViewModel

    var body: some View {
        VStack {
            HStack {
                MenuButton(onTap: onMenuTap)
                Spacer()
                HeaderLogo()
                Spacer()
                ProfileImageView(onTap: onProfileTap,
                                 profileViewModel: profileViewModel)
            }
            .padding(.horizontal)
            .padding(.top, safeAreaTop())
            .padding(.bottom, 8)
            .background(Color.white)
        }
    }

    /// Detects safe area inset (status bar height)
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }
}
