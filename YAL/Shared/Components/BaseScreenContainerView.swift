//
//  BaseScreenContainerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import Combine

struct BaseScreenContainerView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var onTapOutside: (() -> Void)?
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            Image("OTPBg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack {
                content()
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.3), value: keyboardHeight)
            }
        }
        .background(Color("ScreenBg"))
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            onTapOutside?()
        }
        .onAppear {
            observeKeyboard()
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    private func observeKeyboard() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .sink { height in
                keyboardHeight = height
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { _ in
                keyboardHeight = 0
            }
            .store(in: &cancellables)
    }
}
