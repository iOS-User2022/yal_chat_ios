//
//  ChatHistoryView.swift
//  YAL
//
//  Created by Hari krishna on 17/02/26.
//

import SwiftUI

struct ChatHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showArchiveConfirmation = false
    @State private var showClearConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var deleteMediaFromGallery = false
    @State private var deleteStarredMessages = false
    @State private var clearDeleteMediaFromGallery = false
    
    var body: some View {
        ZStack {
            // Dark Background
            Color(hex: "0A171F")
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavigationBar()
                
                // Menu Options
                VStack(spacing: 0) {
                    menuOption(
                        icon: "export_chat",
                        title: "Export Chat",
                        action: { }
                    )
                    
                    menuOption(
                        icon: "archive_chat",
                        title: "Archive all chats",
                        action: {
                            showArchiveConfirmation = true
                        }
                    )
                    
                    menuOption(
                        icon: "clear_chat",
                        title: "Clear all chats",
                        action: {
                            showClearConfirmation = true
                        }
                    )
                    
                    menuOption(
                        icon: "delete_chat",
                        title: "Delete all chats",
                        action: {
                            showDeleteConfirmation = true
                        }
                    )
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .overlay(
            confirmationPopup
        )
    }
    
    // MARK: - Custom Navigation Bar
    private func customNavigationBar() -> some View {
        HStack(spacing: 16) {
            Button(action: {
                dismiss()
            }) {
                Image("back-long")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }
            
            Text("Chat History")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }
    
    // MARK: - Menu Option
    private func menuOption(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image( icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Confirmation Popup
    @ViewBuilder
    private var confirmationPopup: some View {
        if showArchiveConfirmation {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showArchiveConfirmation = false
                    }
                
                VStack(spacing: 0) {
                    Text("Are you sure you want to archive ALL chats?")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white .opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showArchiveConfirmation = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white .opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Handle archive action here
                            showArchiveConfirmation = false
                            // TODO: Add your archive logic
                        }) {
                            Text("Ok")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Design.Color.appGradient)
                                .frame(width: 151, height: 40)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(width: 340)
                .background(Color(hex: "#202D35"))
                .cornerRadius(16)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: showArchiveConfirmation)
        }
        
        if showClearConfirmation {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showClearConfirmation = false
                    }
                
                VStack(spacing: 0) {
                    Text("Clear all chats?")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 16) {
                        CheckboxRow(
                            isChecked: $clearDeleteMediaFromGallery,
                            text: "Also delete media received in chats from media gallery?"
                        )
                        
                        CheckboxRow(
                            isChecked: $deleteStarredMessages,
                            text: "Delete starred messages"
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showClearConfirmation = false
                            clearDeleteMediaFromGallery = false
                            deleteStarredMessages = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white .opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Handle clear action here
                            // TODO: Add your clear logic
                            // Access: clearDeleteMediaFromGallery and deleteStarredMessages
                            showClearConfirmation = false
                            clearDeleteMediaFromGallery = false
                            deleteStarredMessages = false
                        }) {
                            Text("Clear chats")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white .opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Design.Color.appGradient)
                                .frame(width: 151, height: 40)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(width: 340)
                .background(Color(hex: "#202D35"))
                .cornerRadius(16)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: showClearConfirmation)
        }
        
        if showDeleteConfirmation {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showDeleteConfirmation = false
                    }
                
                VStack(spacing: 0) {
                    Text("Delete all chats?")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    CheckboxRow(
                        isChecked: $deleteMediaFromGallery,
                        text: "Also delete media received in chats from media gallery?"
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showDeleteConfirmation = false
                            deleteMediaFromGallery = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white .opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Handle delete action here
                            // TODO: Add your delete logic
                            // Access: deleteMediaFromGallery
                            showDeleteConfirmation = false
                            deleteMediaFromGallery = false
                        }) {
                            Text("Delete All")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Design.Color.appGradient)
                                .frame(width: 151, height: 40)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(width: 340)
                .background(Color(hex: "202D35"))
                .cornerRadius(16)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: showDeleteConfirmation)
        }
    }
}

// MARK: - Checkbox Row Component
struct CheckboxRow: View {
    @Binding var isChecked: Bool
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: {
                isChecked.toggle()
            }) {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Design.Color.appGradient, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isChecked ? Color.white : Color.clear)
                    )
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isChecked ? 1 : 0)
                    )
            }
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
