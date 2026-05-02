//
//  GetStartedView.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//


import SwiftUI


struct GetStartedView: View {
    @StateObject var viewModel: GetStartedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    init() {
        let aViewModel = DIContainer.shared.container.resolve(GetStartedViewModel.self)!
        _viewModel = StateObject(wrappedValue: aViewModel)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Design.Color.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 139)
                Image("YAL Logo 1").frame(width: 40, height: 40)
                Spacer().frame(height: 24)

                // Title
                Text("Enter your Name")
                    .font(Design.Font.heavy(24))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                
                Spacer().frame(height: 12)
                
                // Subtitle
                Text("This will be your display name")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Color.secondryTextColor)
                    .multilineTextAlignment(.center)
                
                Spacer().frame(height: 32)
                
                // Name TextField
                TextField(
                    "",
                    text: $viewModel.name,
                    prompt: Text("Name")
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.7))
                        .font(Design.Font.body)
                )
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(hex: "#202D35"))
                .cornerRadius(8)
                .foregroundColor(Design.Color.primaryTextColor) // 👉 Typed text color
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Design.Color.navy.opacity(0.6), lineWidth: 1)
                        .allowsHitTesting(false)
                )

                
                Spacer().frame(height: 24)
                
                // Let's Chat Button
                Button(action: {
                    viewModel.updateProfileIfNeeded()
                }) {
                    Text("Let’s Chat")
                        .font(Design.Font.bold(16))
                        .foregroundColor((!viewModel.name.isEmpty) ? .white : Design.Color.medium_gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background((!viewModel.name.isEmpty) ? Design.Color.appGradient : Design.Color.disabledGradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 22)
                .disabled(viewModel.name.isEmpty)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .onAppear {
                viewModel.onStepChange = {
                    authViewModel.completeAuth()
                }
            }
            
            Button(action: {
                authViewModel.step = .login
            }) {
                Image("back-long")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .padding(.top, 50)
            .padding(.leading, 20)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea()
    }
}

