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
            
            VStack(spacing: 16) {
                
                // Top icon
                Image(systemName: "nosign")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.red)
                
                // Heading
                Text("Block \(userName)?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryText)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("You won’t receive messages or calls from this user.\nThey won’t be notified that you blocked them.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Block button
                Button(action: {
                    onBlock()
                }) {
                    Text("Block")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Design.Color.appGradient)
                        .cornerRadius(8)
                }
                
                // Cancel button
                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(Design.Color.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 8)
            .padding(.horizontal, 32)
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
                
                // Heading
                Text("Unblock \(userName)?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryText)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("They will be able to message and call you again.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Unblock button
                Button(action: {
                    onUnblock()
                }) {
                    Text("Unblock")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Design.Color.appGradient)
                        .cornerRadius(8)
                }
                
                // Cancel button
                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(Design.Color.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 8)
            .padding(.horizontal, 32)
        }
    }
}
