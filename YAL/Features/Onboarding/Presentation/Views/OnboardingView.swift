//
//  OnboardingView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentPage = 0
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "onboarding1",
            title: "Welcome to YAL.ai",
            description: "Stop scammers before they defraud users."
        ),
        OnboardingPage(
            image: "onboarding2",
            title: "Secure",
            description: "Experience private and secure conversations with no spam or scams. Keep your chats safe and seamless."
        ),
        OnboardingPage(
            image: "onboarding3",
            title: "Alerts",
            description: "YAL.ai monitors messages and provides real time alerts to prevent the fraud."
        ),
        OnboardingPage(
            image: "onboarding4",
            title: "Offline",
            description: "Your data stays on your device. We never send your personal information."
        )
    ]
    
    var body: some View {
        ZStack {
            // White base
            Color.white.ignoresSafeArea()
            
            // Transparent mesh overlay
            Image("onboarding-background")
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
            
            VStack {
                // Rotating content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(alignment: .center, spacing: 0) {
                            Spacer().frame(minHeight: 20, maxHeight: 68)
                            
                            Image(pages[index].image)
                                .resizable()
                                .scaledToFit()
                                .padding(.horizontal, 28)
                            
                            Spacer().frame(maxHeight: 62)
                            
                            Text(pages[index].title)
                                .font(Design.Font.bold(32))
                                .foregroundColor(Design.Color.headingText)
                                .padding(.top, 10)
                            
                            Spacer().frame(height: 7)
                            
                            Text(pages[index].description)
                                .font(Design.Font.regular(16))
                                .foregroundColor(Design.Color.headingText.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hide default dots
//                .frame(height: UIScreen.main.bounds.height * 0.7)
                .onReceive(timer) { _ in
                    withAnimation {
                        currentPage = (currentPage + 1) % pages.count
                    }
                }
                Spacer()

                pageIndicator()
                
                Spacer().frame(height: 32)
                
                // Start button
                Button(action: {
                    authViewModel.initiateLogin()
                }) {
                    HStack {
                        Text("Start Messaging")
                            .font(Design.Font.bold(16))
                        Image("arrow-right-white")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Design.Color.appGradient)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .padding(.horizontal, 12.5)
                    .padding(.bottom, 3)
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 30)
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Private Method for Pagination Dots
    @ViewBuilder
    private func pageIndicator() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Design.Color.appGradient.opacity(1.0) : Design.Color.appGradient.opacity(0.2))
                    .frame(width: currentPage == index ? 8 : 8, height: currentPage == index ? 8 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .frame(height: 8)
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}
