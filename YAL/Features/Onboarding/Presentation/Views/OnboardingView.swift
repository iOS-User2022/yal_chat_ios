//
//  OnboardingView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import SDWebImageSwiftUI

private enum OnboardingTypography {
    static let title = Design.Typography.sfPro.bold(32)
    static let description = Design.Typography.sfPro.regular(16)
    static let button = Design.Typography.sfPro.bold(15)
}

private enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 30
    static let textSpacing: CGFloat = 10
    static let contentSpacing: CGFloat = 20
    static let actionSpacing: CGFloat = 20
    static let actionTopPadding: CGFloat = 16
    static let actionBottomPadding: CGFloat = 24
    static let ctaHeight: CGFloat = 60
    static let ctaCornerRadius: CGFloat = 12

    static let overlayMaxSize: CGFloat = 300

    static let gifMaxWidth: CGFloat = 230
    static let gifAspectRatio: CGFloat = 315.0 / 230.0

    static let pageIndicatorDotSize: CGFloat = 8
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingFlowViewModel()
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        GeometryReader { proxy in
            let overlaySize = min(proxy.size.width * 0.8, OnboardingLayout.overlayMaxSize)
            let gifWidth = min(proxy.size.width * 0.62, OnboardingLayout.gifMaxWidth)
            let gifHeight = gifWidth * OnboardingLayout.gifAspectRatio

            ZStack(alignment: .top) {
                Design.Color.backgroundColor.ignoresSafeArea()

                Image(.particles5)
                    .frame(width: overlaySize, height: overlaySize)

                VStack(spacing: 0) {
                    // First container: centered onboarding content
                    TabView(selection: $viewModel.currentPageIndex) {
                        ForEach(viewModel.slides) { slide in
                            VStack(spacing: OnboardingLayout.contentSpacing) {
                                AnimatedImage(url: slide.gifURL)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: gifWidth, height: gifHeight, alignment: .center)

                                VStack(spacing: OnboardingLayout.textSpacing) {
                                    Text(slide.title)
                                        .font(OnboardingTypography.title)
                                        .foregroundColor(Design.Color.primaryTextColor)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.9)

                                    Text(slide.description)
                                        .opacity(0.8)
                                        .font(OnboardingTypography.description)
                                        .foregroundColor(Design.Color.primaryTextColor)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.9)
                                        .lineSpacing(2)
                                }
                                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .tag(slide.id)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

                    // Second container: top-aligned actions
                    VStack(spacing: OnboardingLayout.actionSpacing) {
                        Button(action: {
                            withAnimation {
                                if viewModel.isOnLastSlide {
                                    onComplete()
                                } else {
                                    viewModel.advanceToNextSlide()
                                }
                            }
                        }) {
                            HStack {
                                Text(viewModel.primaryButtonTitle)
                                    .font(OnboardingTypography.button)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: OnboardingLayout.ctaHeight)
                            .background(Design.Color.appGradient)
                            .foregroundColor(.white)
                            .cornerRadius(OnboardingLayout.ctaCornerRadius)
                        }
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)

                        pageIndicator()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, OnboardingLayout.actionTopPadding)
                    .padding(.bottom, OnboardingLayout.actionBottomPadding)
                }
            }
        }
    }
    
    // MARK: - Private Method for Pagination Dots
    @ViewBuilder
    private func pageIndicator() -> some View {
        HStack(spacing: 8) {
            ForEach(viewModel.slides) { slide in
                Circle()
                    .fill(
                        viewModel.currentPageIndex == slide.id
                        ? Design.Color.white.opacity(1.0)
                        : Design.Color.white.opacity(0.2)
                    )
                    .frame(width: OnboardingLayout.pageIndicatorDotSize, height: OnboardingLayout.pageIndicatorDotSize)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentPageIndex)
            }
        }
        .frame(height: OnboardingLayout.pageIndicatorDotSize)
    }
}
