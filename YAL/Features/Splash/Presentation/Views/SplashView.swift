//
//  SplashView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct SplashView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var animateOut = false
    
    var body: some View {
        ZStack {
            // Background Color
            Design.Color.appGradient
                .ignoresSafeArea()
            
            // Mesh Overlay
            Image("splash-mesh") // your transparent mesh image
                .resizable()
                .scaledToFill()
                .blendMode(.overlay) // overlay blending
                .ignoresSafeArea()
            
            VStack() {
                Spacer()
                
                // Logo Image (speech bubble or robot icon)
                Image("yal-logo-white") // your main logo image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 70)
                
                Spacer().frame(height: 20)
                
                // App Title
                Image("yal-ai") // "YAL.ai" text as image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 148, height: 37)
                
                Spacer().frame(height: 8)
                // Subtitle
                Text("Your Alternative Life")
                    .font(Design.Font.regular(16))
                    .foregroundColor(Color.white)
                    .frame(height: 16)
                
                Spacer()
                
                // Version number at bottom
                Text("App ver. \(appVersion)")
                    .frame(height: 12)
                    .font(Design.Font.medium(12))
                    .foregroundColor(Color.white.opacity(0.8))
                
                Spacer().frame(height: 50)
                
            }
            .padding(.horizontal, 20)
            .background(Design.Color.clear)
        }
        .onAppear {
            FirebaseManager.shared.fetchConfig { needsUpdate, isForce in
                if needsUpdate {
                    DispatchQueue.main.async {
                        router.currentRoute = isForce ? .forceUpdate : .softUpdate
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            animateOut = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            authViewModel.checkLoginStatus()
                        }
                    }
                }
            }
        }
    }
    
    // Read version from Info.plist
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}

