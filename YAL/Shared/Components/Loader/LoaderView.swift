//
//  LoaderView.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/04/25.
//


import SwiftUI

struct LoaderView: View {
    @StateObject private var manager = LoaderManager.shared

    var body: some View {
        Group {
            if manager.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Design.Color.navy))
                            .scaleEffect(1.5)

                        Text("Loading...")
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.navy.opacity(0.8))
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 8)
                    .zIndex(99)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.isLoading)
    }
}
