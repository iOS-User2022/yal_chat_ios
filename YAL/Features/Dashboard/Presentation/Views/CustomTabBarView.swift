//
//  CustomTabBarView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

// MARK: - Tab Enum
enum Tab: String, CaseIterable {
    case sms, chats, calls, contacts
}

// MARK: - Custom Tab Bar
struct CustomTabBarView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
//            TabBarItemView(tab: .sms, isSelected: selectedTab == .sms, unreadCount: 0, onTap: {
//                selectedTab = .sms
//            })
//            
//            Spacer()
            

            TabBarItemView(tab: .contacts, isSelected: selectedTab == .contacts, unreadCount: 0, onTap: {
                selectedTab = .contacts
            })
            
            Spacer()
            
            TabBarItemView(tab: .chats, isSelected: selectedTab == .chats, unreadCount: 0, onTap: {
                selectedTab = .chats
            })
            
            Spacer()

            TabBarItemView(tab: .calls, isSelected: selectedTab == .calls, unreadCount: 0, onTap: {
                selectedTab = .calls
            })
        }
    }
}

#Preview {
    CustomTabBarView(selectedTab: .constant(.sms))
}
