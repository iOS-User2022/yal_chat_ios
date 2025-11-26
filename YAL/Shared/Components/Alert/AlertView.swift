//
//  AlertView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct AlertView: View {
    let model: AlertViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 16) {
                if let image = UIImage(named: model.imageName ?? "") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                }
                Text(model.title)
                    .font(Design.Font.subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Design.Color.primaryText)
                
                Text(model.subTitle)
                    .font(Design.Font.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Design.Color.grayText)

                // Conditionally display actions horizontally or vertically based on the number of actions
                if model.actions.count <= 2 {
                    HStack(spacing: 16) {
                        ForEach(model.actions) { actionModel in
                            Button(action: {
                                onDismiss()
                                actionModel.action()
                            }) {
                                Text(actionModel.title)
                                    .font(Design.Font.button)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Design.Color.appGradient)
                                    .foregroundColor(Design.Color.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 16) {
                        ForEach(model.actions) { actionModel in
                            Button(action: {
                                onDismiss()
                                actionModel.action()
                            }) {
                                Text(actionModel.title)
                                    .font(Design.Font.button)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Design.Color.appGradient)
                                    .foregroundColor(Design.Color.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 12)
            .padding(.horizontal, 32)
        }
    }
    
    private func background(for style: AlertActionStyle) -> Color {
        switch style {
        case .primary: return Color.blue
        case .secondary: return Color.gray.opacity(0.2)
        case .destructive: return Color.red
        }
    }
    
    private func foreground(for style: AlertActionStyle) -> Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return .black
        }
    }
}
