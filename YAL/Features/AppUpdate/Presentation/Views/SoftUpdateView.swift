//
//  SoftUpdateView.swift
//  YAL
//
//  Created by Vishal Bhadade on 01/05/25.
//

import SwiftUI

struct SoftUpdateView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Update Available")
                .font(Design.Font.heavy(24))
                .foregroundColor(Design.Color.primaryText)

            Text("A new version of YAL.ai is available. Please consider updating.")
                .multilineTextAlignment(.center)
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                .padding(.horizontal)

            VStack(spacing: 16) {
                if let appStoreURL = FirebaseManager.shared.appStoreURL {
                    Button(action: {
                        UIApplication.shared.open(appStoreURL)
                    }) {
                        Text("Update Now")
                            .font(Design.Font.button)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Design.Color.appGradient)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                    }
                } else {
                    Text("⚠️ App Store link not available.")
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Button(action: {
                    authViewModel.checkLoginStatus()
                }) {
                    Text("Continue Anyway")
                        .font(Design.Font.button)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Design.Color.appGradient)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding()
    }
}
