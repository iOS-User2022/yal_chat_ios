//
//  TabBarItemView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI

struct TabBarItemView: View {
    let tab: Tab
    let isSelected: Bool
    let unreadCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom){
                if isSelected {
                    Image("tabGradient")
                        .frame(width: 100, height: 60)
                        .ignoresSafeArea(edges: .bottom)
                }

                VStack(spacing: 4) {
                    
                    ZStack(alignment: .center) {
                        
                        Image(iconName)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .scaleEffect(iconScale)
                        //.padding(8)
                        
                        if unreadCount > 0 {
                            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                .font(Design.Font.semiBold(10))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Design.Color.appGradient)
                                .clipShape(Circle())
                                .offset(x: 10, y: -5)
                        }
                    }
                    
                    Text(tabLabel)
                        .font(isSelected ? Design.Font.bold(10) : Design.Font.medium(10))
                        .foregroundColor(isSelected ? Design.Color.primaryTextColor : Design.Color.secondryTextColor)
                    
                    
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var tabLabel: String {
        switch tab {
        case .sms: return "SMS"
        case .chats: return "Chats"
        case .calls: return "Calls"
        case .contacts: return "Contacts"
        }
    }
    
    private var iconName: String {
        switch tab {
        case .sms: return isSelected ? "sms-selected" : "sms"
        case .chats: return isSelected ? "chats-selected" : "chats"
        case .calls: return isSelected ? "calls-selected" : "calls"
        case .contacts: return isSelected ? "contacts-selected" : "contacts"
        }
    }
    
    private var iconScale: CGFloat {
        if tab == .sms && !isSelected {
            return 1.4
        } else {
            return 1.0
        }
    }
}
