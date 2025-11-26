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
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                }
                .toggleStyle(CheckboxToggleStyle())
                
                HStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.headingDark)
                        }
                        
                        Button(action: { onDelete() }) {
                            Text("Delete \(isGroup ? "group" : "chat")")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.headingDark)
                        }
                    }
                }
                
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}
