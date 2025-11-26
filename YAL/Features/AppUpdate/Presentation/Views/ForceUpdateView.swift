//
//  ForceUpdateView.swift
//  YAL
//
//  Created by Vishal Bhadade on 01/05/25.
//

import SwiftUI

struct ForceUpdateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("Update Required")
                .font(Design.Font.heavy(24))
                .foregroundColor(Design.Color.primaryText)
            
            Text("Please update the app to continue using YAL.ai")
                .multilineTextAlignment(.center)
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                .padding(.horizontal, 24)
            
            Spacer().frame(height: 24)
            
            if let appStoreURL = FirebaseManager.shared.appStoreURL {
                Button(action: {
                    UIApplication.shared.open(appStoreURL)
                }) {
                    Text("Go to App Store")
                        .font(Design.Font.button)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Design.Color.appGradient)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
            } else {
                Text("⚠️ App Store link not available.")
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            Spacer()
        }
        .padding()
        .interactiveDismissDisabled(true) // Prevent dismissal on force update
    }
}
