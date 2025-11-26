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
            VStack(spacing: 0) {
                Spacer().frame(height: 139)
                
                // Title
                Text("Enter your Full Name")
                    .font(Design.Font.heavy(24))
                    .foregroundColor(Design.Color.headingText)
                    .multilineTextAlignment(.center)
                
                Spacer().frame(height: 12)
                
                // Subtitle
                Text("This will be used as your display name.")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Color.secondaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Spacer().frame(height: 32)
                
                // Name TextField
                TextField(
                    "",
                    text: $viewModel.name,
                    prompt: Text("Enter your name")
                        .foregroundColor(Design.Color.secondaryText.opacity(0.7))
                        .font(Design.Font.body)
                )
                .padding()
                .background(Design.Color.white)
                .cornerRadius(8)
                .foregroundColor(Design.Color.primaryText) // 👉 Typed text color
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Design.Color.navy.opacity(0.6), lineWidth: 1)
                        .allowsHitTesting(false)
                )

                
                Spacer().frame(height: 124)
                
                // Let's Chat Button
                Button(action: {
                    viewModel.updateProfileIfNeeded()
                }) {
                    Text("Let’s Chat")
                        .font(Design.Font.bold(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Design.Color.appGradient)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 12.5)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .background(Design.Color.white)
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

