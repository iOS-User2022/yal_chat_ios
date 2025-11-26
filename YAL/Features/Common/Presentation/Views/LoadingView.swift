//
//  LoadingView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//


import SwiftUI

struct LoadingView: View {
    @StateObject private var viewModel: LoadingViewModel

    init() {
        let aViewModel = DIContainer.shared.container.resolve(LoadingViewModel.self)!
        _viewModel = StateObject(wrappedValue: aViewModel)
    }

    var body: some View {
        ZStack {
            Design.Background.radialGlow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Image("AppIcon")
                    .resizable()
                    .frame(width: 87, height: 87)

                Spacer().frame(height: 60)

                HStack(spacing: 5) {
                    Spacer()
                    Text("\(Int(viewModel.progress))")
                        .font(Design.Font.bold(32))
                        .foregroundColor(Design.Color.primaryText)
                    Text("%")
                        .font(Design.Font.button)
                        .foregroundColor(Design.Color.mediumGray)
                    Spacer()
                }
                .frame(height: 32, alignment: .centerFirstTextBaseline)

                Spacer().frame(height: 12)

                Text("We are fetching your data.")
                    .font(Design.Font.button)
                    .foregroundColor(Design.Color.darkText.opacity(0.65))
                    .opacity(0.8)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 4)
        }
        .padding(.horizontal, 28)
        .ignoresSafeArea()
        .onAppear {
            viewModel.start()
        }
        .onChange(of: viewModel.isComplete) { isDone in
            if isDone {
                print("✅ Done")
            }
        }
    }
}
