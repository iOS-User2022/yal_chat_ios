//
//  RootContainer.swift
//  YAL
//
//  Created by Vishal Bhadade on 12/04/25.
//

import SwiftUI

struct RootContainer: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var privacyManager = PrivacyProtectionManager()
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        ZStack {
            switch router.currentRoute {
            case .splash:
                SplashView()

            case .login:
                AuthFlowView()

            case .dashboard:
                TabContainerView()

            case .onboarding:
                OnboardingView()
            
            case .tutorial:
                TutorialView()
                
            case .loading:
                LoadingView()

            case .profile:
                ProfileView(navPath: .constant(NavigationPath()))

            case .settings:
                SettingsView()

            case .softUpdate:
                SoftUpdateView()
                
            case .forceUpdate:
                ForceUpdateView()
                
            default:
                EmptyView() // fallback
            }

            LoaderView() // ⬅️🔥 Always overlayed above any screen

            if appSettings.disableScreenshot {
                if privacyManager.showPrivacyOverlay {
                    PrivacyOverlayView(isVisible: $privacyManager.showPrivacyOverlay)
                }
            }
            

        }.environmentObject(privacyManager)

    }
}
