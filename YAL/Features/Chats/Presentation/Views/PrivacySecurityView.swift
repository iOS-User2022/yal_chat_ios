//
//  PrivacySecurityView.swift
//  YAL
//
//  Created by Hari krishna on 05/02/26.
//

import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var roomViewModel: RoomListViewModel
    @State private var showEmptyBlockedAlert = false
    
    init() {
        let vm = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _roomViewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    
                    Text("Settings / Privacy and Security")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .padding(.top, 50) // Add extra padding for status bar
                .background(Color(hex: "#0A1929"))
                
                // Blocked User Row - Conditional Navigation
                if roomViewModel.blockedRooms.count > 0 {
                    NavigationLink(destination: BlockedUserListView(roomViewModel: roomViewModel)) {
                        SettingRow(
                            icon: "user-remove",
                            title: "Blocked User",
                            trailing: "\(roomViewModel.blockedRooms.count)",
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 20)
                } else {
                    Button {
                        showEmptyBlockedAlert = true
                    } label: {
                        SettingRow(
                            icon: "user-remove",
                            title: "Blocked User",
                            trailing: "\(roomViewModel.blockedRooms.count)",
                            showChevron: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 20)
                }
                
                // Passcode Lock Row
                Button {
                    // Handle passcode lock tap
                } label: {
                    SettingRow(
                        icon: "key",
                        title: "Passcode lock",
                        subtitle: "Off",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Privacy Section Header
                Text("Privacy")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                
                // Privacy Options
                Button {
                    // Handle phone number privacy tap
                } label: {
                    PrivacyOptionRow(
                        question: "Who can see my phone number?",
                        answer: "My Contacts",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    // Handle profile photos privacy tap
                } label: {
                    PrivacyOptionRow(
                        question: "Who can see my profile photos?",
                        answer: "Everybody",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    // Handle bio privacy tap
                } label: {
                    PrivacyOptionRow(
                        question: "Bio",
                        answer: "Everybody",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    // Handle date of birth privacy tap
                } label: {
                    PrivacyOptionRow(
                        question: "Date of Birth",
                        answer: "My Contacts",
                        showChevron: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .background(Color(hex: "#0A1929"))
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .alert("No Blocked Users", isPresented: $showEmptyBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You don't have any blocked users.")
        }
        .onAppear {
            roomViewModel.loadRooms()
        }
    }
}

// Privacy Option Row Component
struct PrivacyOptionRow: View {
    let question: String
    let answer: String
    var showChevron: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(question)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(hex: "#0A1929"))
    }
}

// Settings Row Component
struct SettingRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var showChevron: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(hex: "#0A1929"))
    }
}
