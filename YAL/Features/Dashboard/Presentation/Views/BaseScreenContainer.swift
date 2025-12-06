//
//  BaseScreenContainer.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/04/25.
//


import SwiftUI

struct BaseScreenContainer<Content: View, BottomBar: View>: View {
    var onMenuTap: () -> Void = {}
    var onProfileTap: () -> Void = {}
    var bottomBar: (() -> BottomBar)? = nil
    @ObservedObject var profileViewModel: ProfileViewModel
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                onMenuTap: onMenuTap,
                onProfileTap: onProfileTap,
                profileViewModel: profileViewModel
            )
            .padding(.horizontal, 8)
            .padding(.top, 12)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let bottomBar = bottomBar {
                bottomBar()
            }
        }
        .background(Design.Color.white)
        .ignoresSafeArea(edges: .bottom)
    }
}
