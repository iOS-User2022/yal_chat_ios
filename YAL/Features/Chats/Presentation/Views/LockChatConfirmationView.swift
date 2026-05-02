//
//  LockChatConfirmationView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 23/10/25.
//

import SwiftUI

struct LockChatConfirmationView: View {
    let onLock: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(UIConstants.Opacity.overlay)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: UIConstants.Layout.formSpacing) {
                
                // Title
                Text(Constants.lockThisChat.localized)
                    .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(Constants.lockedChatsDesc.localized)
                    .font(Design.Font.regular(UIConstants.Layout.Height.iconSmallest))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, UIConstants.Layout.Radius.small)
                
                // Lock button
                Button(action: { onLock() }) {
                    Text(Constants.lock.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .background(Design.Color.appGradient)
                        .cornerRadius(UIConstants.Layout.Radius.small)
                }
                
                // Cancel button
                Button(action: { onCancel() }) {
                    Text(Constants.cancel.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                        .foregroundColor(Design.Color.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .background(Color.gray.opacity(UIConstants.Opacity.veryLow))
                        .cornerRadius(UIConstants.Layout.Radius.small)
                }
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(UIConstants.Layout.formSpacing)
            .shadow(radius: UIConstants.Layout.Radius.small)
            .padding(.horizontal, UIConstants.Layout.formSpacing)
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
            Color.black.opacity(UIConstants.Opacity.overlay)
                .ignoresSafeArea()
                .onTapGesture { onCancel?() }
            
            VStack(spacing: UIConstants.Layout.formSpacing) {
                
                // Title
                Text(Constants.secureYourChats.localized)
                    .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                // Lock icon
                Image(UIConstants.Symbols.lockBlack)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.white)
                    .scaledToFit()
                    .frame(width: UIConstants.Layout.ActionButton.height, height: UIConstants.Layout.ActionButton.height)
                    .foregroundColor(Design.Color.primaryTextColor)
                    .padding(.top, UIConstants.Layout.Radius.small)
                
                // Subtitle
                Text(Constants.protectChatsDesc.localized)
                    .font(Design.Font.regular(UIConstants.Layout.Height.iconSmallest))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, UIConstants.Layout.Radius.small)
                
                // Use Biometrics button
                Button(action: { onUseBiometrics() }) {
                    Text(Constants.useBiometrics.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .background(Design.Color.appGradient)
                        .cornerRadius(UIConstants.Layout.Radius.small)
                }
                
                // Set 4-digit PIN button
                Button(action: { onSetPIN() }) {
                    Text(Constants.setPinTitle.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                        .foregroundColor(Design.Color.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .background(Color.gray.opacity(UIConstants.Opacity.veryLow))
                        .cornerRadius(UIConstants.Layout.Radius.small)
                }
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(UIConstants.Layout.formSpacing)
            .shadow(radius: UIConstants.Layout.Radius.small)
            .padding(.horizontal, UIConstants.Layout.horizontalPadding)
        }
    }
}

struct ChatsProtectedView: View {
    let onContinue: () -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(UIConstants.Opacity.overlay)
                .ignoresSafeArea()
                .onTapGesture { onCancel?() }
            
            VStack(spacing: UIConstants.Layout.formSpacing) {
                
                // Checkmark icon
                Image(UIConstants.Symbols.checkMark)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.white)
                    .scaledToFit()
                    .frame(width: UIConstants.Layout.ActionButton.height, height: UIConstants.Layout.ActionButton.height)
                    .foregroundColor(.green)
                    .padding(.top, UIConstants.Layout.Radius.small)
                
                // Title
                Text(Constants.chatsProtectedTitle.localized)
                    .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(Constants.chatsProtectedDesc.localized)
                    .font(Design.Font.regular(UIConstants.Layout.Height.iconSmallest))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, UIConstants.Layout.Radius.small)
                
                // Continue button
                Button(action: { onContinue() }) {
                    Text(Constants.continueAction.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.formSpacing))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, UIConstants.Layout.internalPadding)
                        .background(Design.Color.appGradient)
                        .cornerRadius(UIConstants.Layout.Radius.small)
                }
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(UIConstants.Layout.formSpacing)
            .shadow(radius: UIConstants.Layout.Radius.small)
            .padding(.horizontal, UIConstants.Layout.formSpacing)
        }
    }
}
