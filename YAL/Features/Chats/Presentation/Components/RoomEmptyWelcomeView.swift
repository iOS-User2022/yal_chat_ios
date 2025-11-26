//
//  RoomEmptyWelcomeView.swift
//  YAL
//
//  Created by Vishal Bhadade on 22/05/25.
//

import SwiftUI

struct RoomEmptyWelcomeView: View {
    let startChatAction: () -> Void
    let inviteFriendAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 32, maxHeight: 61)
            
            Text("Welcome to Yal.ai")
                .font(Design.Font.bold(32))
                .foregroundColor(Design.Color.primaryText)
                .padding(.horizontal, 30)
            
            Spacer().frame(height: 8)

            Text("Start your first conversation or invite friends to join you!")
                .font(Design.Font.regular(16))
                .multilineTextAlignment(.center)
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                .padding(.horizontal, 30)
            
            Spacer().frame(height: 32)

            Image("welcome-chat") // Replace with your asset name, or use SF Symbol if needed
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
            
            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                Button(action: startChatAction) {
                    Text("Start a Chat")
                        .font(Design.Font.bold(18))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Design.Color.appGradient)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                
                Button(action: inviteFriendAction) {
                    Text("Invite a Friend")
                        .font(Design.Font.bold(18))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.white)
                        .foregroundColor(Color(hex: "#1162A5"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Design.Color.navy, lineWidth: 1.0)
                        )
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .background(Design.Color.appGradient.opacity(0.2))
        .frame(alignment: .top)
    }
}
