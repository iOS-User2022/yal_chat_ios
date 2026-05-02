//
//  SettingsView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) var openURL
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: SettingsViewModel
    @Binding var navPath: NavigationPath
    
    init(navPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        let viewModel = DIContainer.shared.container.resolve(SettingsViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        self._navPath = navPath
    }
    
    var body: some View {
        ZStack {
            
            // MARK: - Full Gradient Background
            Color(hex: "#0A171F")
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    Spacer().frame(height: 56)
                    
                    // MARK: - Custom NavBar
                    HStack(spacing: 16) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image("back-long")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        
                        Text("Settings")
                            .font(Design.Font.semiBold(14))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 44)
                    
                    // MARK: - Settings List
                    
                    VStack(spacing: 0) {
                        
                        navigableSettingRow("Chat Settings", icon: "messages_icon") {
                            ChatSettingsView()
                        }
                        settingRow("Notification and Sounds", icon: "notification-mute") {
                            navPath.append(ProfileRoute.notifications)
                        }
                        
                        settingRow("Privacy and Security", icon: "privacy_policy") {
                            navPath.append(ProfileRoute.blocked)
                        }
                        
                        // Gradient Divider
                        gradientDivider
                        
                        settingRow("Term of Service", icon: "terms-of-service") {
                            open("https://www.yal.chat/terms-of-service")
                        }
                        settingRow("About App", icon: "info") {
                            open("https://www.yal.chat/about-us")
                        }
                        
                        settingRow("FAQs", icon: "faqs") {
                            open("https://www.yal.chat/faq")
                        }
                        
                        // Gradient Divider
                        gradientDivider
                        
                        destructiveRow("Logout", icon: "logout") {
                            authViewModel.logout()
                        }
                        
                        destructiveRow("Delete Account", icon: "delete-account") {
                            authViewModel.logout()
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func navigableSettingRow<Destination: View>(
        _ title: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 16) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(.white)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(Design.Font.bold(14))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
}

// MARK: - Components

extension SettingsView {
    
    private func settingRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(.white)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(Design.Font.bold(14))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
    
    private func destructiveRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(Design.Color.destructiveRed)
                
                Text(title)
                    .foregroundColor(Design.Color.white)
                    .font(Design.Font.semiBold(14))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
    
    private var gradientDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue,
                        Color.purple
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }
    
    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}
