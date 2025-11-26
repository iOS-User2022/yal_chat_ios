//
//  LockChatConfirmationView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 23/10/25.
//

import SwiftUI

import SwiftUI

struct LockChatConfirmationView: View {
    let onLock: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 16) {
                
                // Title
                Text("Lock this chat?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryText)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("This chat will be moved to Locked Chats. You’ll need your PIN, Face ID, or fingerprint to open it.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Lock button
                Button(action: { onLock() }) {
                    Text("Lock")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Design.Color.appGradient)
                        .cornerRadius(8)
                }
                
                // Cancel button
                Button(action: { onCancel() }) {
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

struct SecureYourChatsView: View {
    let onUseBiometrics: () -> Void
    let onSetPIN: () -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel?() }
            
            VStack(spacing: 16) {
                
                // Title
                Text("Secure your chats")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryText)
                    .multilineTextAlignment(.center)
                
                // Lock icon
                Image("lockBlack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Design.Color.primaryText)
                    .padding(.top, 8)
                
                // Subtitle
                Text("Protect your chats with a PIN or your device’s biometrics.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Use Biometrics button
                Button(action: { onUseBiometrics() }) {
                    Text("Use Biometrics")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Design.Color.appGradient)
                        .cornerRadius(8)
                }
                
                // Set 4-digit PIN button
                Button(action: { onSetPIN() }) {
                    Text("Set a 4-digit PIN")
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

struct ChatsProtectedView: View {
    let onContinue: () -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel?() }
            
            VStack(spacing: 16) {
                
                // Checkmark icon
                Image("Check Mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.green)
                    .padding(.top, 8)
                
                // Title
                Text("Your chats are now protected")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.primaryText)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Your chats are secured. Access them using your PIN or device biometrics.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Continue button
                Button(action: { onContinue() }) {
                    Text("Continue")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Design.Color.appGradient)
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
