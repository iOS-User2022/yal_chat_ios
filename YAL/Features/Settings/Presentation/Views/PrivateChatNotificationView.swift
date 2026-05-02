//
//  PrivateChatNotificationView.swift
//  YAL
//
//  Created by Hari krishna on 18/02/26.
//

import SwiftUI

// MARK: - Private Chat Notification Detail View
struct PrivateChatNotificationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isEnabled: Bool = true
    @State private var showPreview: Bool = true
    @State private var soundEnabled: Bool = true
    @State private var vibrateEnabled: Bool = true
    
    var body: some View {
        ZStack {
            Color(hex: "0A171F").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav Bar
                HStack(spacing: 16) {
                    Button { dismiss() } label: {
                        Image("back-long")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                    Text("Notifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // MARK: Notify me about... section
                        VStack(spacing: 0) {
                            Text("Notify me about...")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color(hex: "#F7F7F7"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            
                            HStack {
                                Text("New messages in private chats")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $isEnabled)
                                    .toggleStyle(GradientToggleStyle(
                                        gradient: LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    ))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .cornerRadius(12)
                        }
                        
                        // Gradient Divider
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        // MARK: Setting section
                        VStack(spacing: 0) {
                            Text("Setting")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color(hex: "#F7F7F7"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 0) {
                                settingRow(
                                    icon: "show_message",
                                    title: "Show Message Preview",
                                    subtitle: "Banner",
                                    isOn: $showPreview
                                )
                                settingRow(
                                    icon: "ringtone",
                                    title: "Sound",
                                    subtitle: "Default (system)",
                                    isOn: $soundEnabled
                                )
                                settingRow(
                                    icon: "vibrate",
                                    title: "Vibrate",
                                    subtitle: "Default (system)",
                                    isOn: $vibrateEnabled
                                )
                            }
                            .cornerRadius(12)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        //                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .animation(.easeInOut(duration: 0.25), value: isEnabled)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: [.top, .bottom])
    }
    
    private func settingRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image( icon)
                .resizable()
                .scaledToFit()
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: isOn)
                .toggleStyle(GradientToggleStyle(
                    gradient: LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ))
                .fixedSize() 
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
