//
//  AuthFlowView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        switch authViewModel.step {
        case .login:
            LoginView()
        case .otpVerification(let phone):
            OTPView(phone: phone)
        case .gettingStarted:
            GetStartedView()
        case .completeAuth:
            EmptyView()
        }
    }
}
