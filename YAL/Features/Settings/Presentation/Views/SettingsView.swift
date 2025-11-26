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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 56)
                        // ✅ Custom NavBar
                        HStack(spacing: 20) {
                            Button(action: {
                                dismiss()
                            }) {
                                Image("back-long")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Spacer().frame(width: 20)
                            Text("Settings")
                                .font(Design.Font.heavy(16))
                                .foregroundColor(Design.Color.headingText)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer().frame(height: 44)
                        
                        ScrollView {
                            VStack(spacing: 0) {

                                // MARK: Terms / About / FAQ
                                sectionBox {
                                    settingRow("Notification Settings", icon: "notification-mute") {
                                        navPath.append(ProfileRoute.notifications)
                                    }
                                    
                                    Spacer().frame(height: 4)
                                    
                                    settingRow("Term of Service", icon: "terms-of-service") {
                                        open("https://www.yal.chat/terms-of-service")
                                    }
                                    
                                    Spacer().frame(height: 4)
                                    
                                    settingRow("About App", icon: "info") {
                                        open("https://www.yal.chat/about-us")
                                    }
                                    
                                    Spacer().frame(height: 4)
                                    
                                    settingRow("FAQs", icon: "faqs") {
                                        open("https://www.yal.chat/faq")
                                    }
                                }
                                
                                Spacer().frame(height: 8)
                                
                                // MARK: Logout & Delete
                                sectionBox {
                                    destructiveRow("Logout", icon: "logout") {
                                        authViewModel.logout()
                                    }
                                    
                                    Spacer().frame(height: 4)
                                    
                                    destructiveRow("Delete Account", icon: "delete-account") {
                                        authViewModel.logout()
                                    }
                                }
                                
                                Spacer()
                            }
                            .background(Design.Color.appGradient.opacity(0.12))
                        }
                    }
                    .background(Design.Color.white)
                    
                }
                .background(Design.Color.white)
                // Footer
                footer
            }
            .ignoresSafeArea(.all, edges: [.top, .bottom])
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers

    private var footer: some View {
        VStack {
            Divider()
            HStack(spacing: 12) {
                Image("yal-shield")
                    .resizable()
                    .frame(width: 52, height: 52)
                    .foregroundColor(.blue)
                Text("YAL.ai never sends your personal information to the cloud. Your data stays on your device.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .inset(by: 0.5)
                .stroke(Design.Color.backgroundMuted, lineWidth: 1)
            
        )
    }
    private func sectionBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.white)
    }

    private func settingRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                Text(title)
                    .foregroundColor(Design.Color.headingText)
                    .font(Design.Font.bold(14))
                Spacer()
                Image("arrow-right")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func destructiveRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                Text(title)
                    .foregroundColor(Design.Color.destructiveRed)
                    .font(Design.Font.bold(14))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    #if DEBUG
    private func testRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(Design.Color.headingText)
                    .font(Design.Font.bold(14))
                Text(subtitle)
                    .foregroundColor(Design.Color.secondaryText)
                    .font(Design.Font.regular(11))
            }
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundColor(Design.Color.secondaryText.opacity(0.5))
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    #endif

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}
