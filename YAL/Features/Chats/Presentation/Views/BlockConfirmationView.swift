//
//  BlockConfirmationView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 26/09/25.
//

import SwiftUI

struct BlockConfirmationView: View {
    let userName: String
    let onBlock: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 20) {
                
                // Top icon
                Image("no_sign")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.red)
                
                // Heading
                Text("Block \(userName)?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("You won't receive messages or calls from this user.\nThey won't be notified that you blocked them.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 4)
                
                HStack(spacing: 12) {
                    // Cancel button
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(Design.Font.semiBold(15))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Design.Color.appGradient)
                            .cornerRadius(6)
                    }
                    
                    // Block button
                    Button(action: {
                        onBlock()
                    }) {
                        Text("Block")
                            .font(Design.Font.semiBold(15))
                            .foregroundColor(Design.Color.mediumGray.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.gray.opacity(0))
                            .cornerRadius(6)
                            .overlay(
                                       RoundedRectangle(cornerRadius: 10)
                                           .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                                   )
                    }
                }
            }
            .padding(24)
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 40)
        }
    }
}

struct UnblockConfirmationView: View {
    let userName: String
    let onUnblock: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 16) {
                
                // Top icon
                Image("no_sign")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.red)
                    .padding([.top, .leading], 4)
                
                // Heading
                Text("Unblock \(userName)?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding([.top, .leading], 4)
                
                // Subtitle
                Text("They will be able to message and call\nyou again.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                // Unblock button
                Button(action: {
                    onUnblock()
                }) {
                    Text("Unblock")
                        .font(Design.Font.semiBold(15))
                        .foregroundColor(.white)
                        .frame(width: 113, height: 44)  // Fixed width and height
                        .background(Design.Color.appGradient)
                        .cornerRadius(6)
                }
                
                // Cancel button
                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(Design.Font.semiBold(15))
                        .foregroundColor(Design.Color.mediumGray.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(width: 104, height: 44)  // Fixed width and height
                        .background(Color.gray.opacity(0))
                        .cornerRadius(6)
                        .overlay(
                                   RoundedRectangle(cornerRadius: 10)
                                       .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                               )
                }
                .padding(.bottom, 6)
                
            }
            .padding(.horizontal, 35)
            .padding(.vertical, 20)
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        }
    }
}
