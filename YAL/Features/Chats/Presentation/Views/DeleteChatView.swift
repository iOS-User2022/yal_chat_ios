//
//  DeleteChatView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 26/09/25.
//

import SwiftUI

struct DeleteChatView: View {
    @State private var alsoDeleteMedia = false
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var isGroup: Bool = true
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Delete this \(isGroup ? "group" : "chat")?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.destructiveRed)
                
                Toggle(isOn: $alsoDeleteMedia) {
                    Text("Also delete media received in this group from the device gallery")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                }
                .toggleStyle(CheckboxToggleStyle())
                
                HStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.primaryTextColor)
                        }
                        
                        Button(action: { onDelete() }) {
                            Text("Delete \(isGroup ? "group" : "chat")")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.destructiveRed)
                        }
                    }
                }
                
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}


struct ClearChatView: View {
    @State private var alsoDeleteMedia = false
    let onClear: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Clear this chat?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.destructiveRed)
                
                Toggle(isOn: $alsoDeleteMedia) {
                    Text("Also delete media received in this chat from the device gallery")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                }
                .toggleStyle(CheckboxToggleStyle())
                
                HStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.primaryTextColor)
                        }
                        
                        Button(action: { onClear() }) {
                            Text("Clear chat")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.destructiveRed)
                        }
                    }
                }
                
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}

struct ExitGroupView: View {
    @State private var alsoDeleteMedia = false
    let onExit: () -> Void
    let onExitAndClearChat: () -> Void
    let onCancel: () -> Void
    
    var groupName: String = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Exit Group \(groupName)?")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(Design.Color.destructiveRed)
                
                Toggle(isOn: $alsoDeleteMedia) {
                    Text("Only admins are notified when you leave a group")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.6))
                }
                .toggleStyle(CheckboxToggleStyle())
                
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 24) {
                        Button(action: { onExit() }) {
                            Text("Exit group")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.primaryTextColor)
                        }
                        Button(action: { onExitAndClearChat() }) {
                            Text("Exit and delete for me")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.primaryTextColor)
                        }
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.primaryTextColor)
                        }
                    }
                }
                
            }
            .padding()
            .background(Color(Design.Color.darkgrayColor))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}
