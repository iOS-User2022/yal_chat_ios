//
//  OTPView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI
import Combine

struct OTPView: View {
    @State private var resendTimer = 30
    @State private var timerRunning = true
    @State private var resendTimerCancellable: AnyCancellable?

    @StateObject private var viewModel: OtpViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedIndex: Int?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showAlert: Bool = false

    private var isOTPComplete: Bool {
        viewModel.digits.joined().count == 6
    }

    init(phone: String) {
        let resolvedVM = DIContainer.shared.container.resolve(OtpViewModel.self, argument: phone)!
        _viewModel = StateObject(wrappedValue: resolvedVM)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                mainContent(geometry: geometry)
                backButton()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .ignoresSafeArea()
        }
        .onAppear {
            setupCallbacks()
        }
        if showAlert, let alertModel = viewModel.alertModel {
            AlertView(model: alertModel) {
                showAlert = false
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: geometry.safeAreaInsets.top + 139)
            headingSection()
            Spacer().frame(height: 12)
            subHeadingSection()
            Spacer().frame(height: 24)
            otpInputFields()
            Spacer().frame(height: 16)
            resendSection()
            Spacer().frame(height: 48)
            verifyButton()
            Spacer()
            errorSection()
        }
        .padding(.horizontal, 30)
        .background(Color.white)
        .onAppear {
            startTimer()
            observeVerification()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headingSection() -> some View {
        Text("Check your Message")
            .font(Design.Font.bold(24))
            .foregroundColor(Design.Color.headingText)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func subHeadingSection() -> some View {
        (
            Text("We’ve sent a 6-digit code to\n\(viewModel.maskedPhone). Make sure you enter correct code. ")
                .foregroundColor(Design.Color.headingText.opacity(0.7))
                .font(Design.Font.body)
            +
            Text("Edit No.")
                .foregroundColor(Design.Color.navy)
                .underline()
                .font(Design.Font.bold(16))
        )
        .multilineTextAlignment(.center)
        .onTapGesture {
            Storage.delete(.userExist, type: .userDefaults)
            authViewModel.step = .login
        }
    }

    @ViewBuilder
    private func otpInputFields() -> some View {
        ZStack {
            hiddenTextField()
            otpBoxes()
        }
    }

    @ViewBuilder
    private func resendSection() -> some View {
        if resendTimer > 0 {
            (
                Text("00:\(String(format: "%02d", resendTimer)) ")
                    .foregroundColor(Design.Color.grayText)
                    .font(Design.Font.body)
                +
                Text("Resend")
                    .foregroundColor(Design.Color.navy.opacity(0.45))
                    .underline()
                    .font(Design.Font.body)
            )
            .allowsHitTesting(false)
        } else {
            (
                Text("Didn't receive the code ")
                    .foregroundColor(Design.Color.grayText)
                    .font(Design.Font.body)
                +
                Text("Resend")
                    .foregroundColor(Design.Color.navy)
                    .underline()
                    .font(Design.Font.bold(16))
            )
            .onTapGesture {
                viewModel.resendOTP()
                viewModel.clearOTP()
            }
        }
    }

    @ViewBuilder
    private func verifyButton() -> some View {
        Button(action: {
            viewModel.verifyOtp() {
                hideKeyboard()
                self.viewModel.showAlertForDeniedPermission()
                showAlert = true
            }
        }) {
            HStack(spacing: 12) {
                Spacer()
                Text("Verify")
                Image("arrow-right-white")
                    .resizable()
                    .frame(width: 20, height: 20)
                Spacer()
            }
            .font(Design.Font.button)
            .foregroundColor(.white)
            .padding()
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                isOTPComplete ? Design.Color.appGradient.opacity(1.0) : Design.Color.appGradient.opacity(0.6)
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 12.5)
        .disabled(!isOTPComplete || viewModel.isVerifying)
    }

    @ViewBuilder
    private func errorSection() -> some View {
        if viewModel.showError {
            Text(viewModel.errorMessage)
                .foregroundColor(.red)
                .padding(.bottom, 12)
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func hiddenTextField() -> some View {
        TextField("", text: Binding(
            get: { viewModel.digits.joined() },
            set: { newValue in
                let cleaned = String(newValue.prefix(6))
                for (i, char) in cleaned.enumerated() {
                    if i < viewModel.digits.count {
                        viewModel.digits[i] = String(char)
                    }
                }
                for i in cleaned.count..<viewModel.digits.count {
                    viewModel.digits[i] = ""
                }
            }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .focused($focusedIndex, equals: 0)
    }

    @ViewBuilder
    private func otpBoxes() -> some View {
        HStack(spacing: 16) {
            ForEach(0..<6, id: \.self) { index in
                otpBox(index: index)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedIndex = 0
        }
    }

    @ViewBuilder
    private func otpBox(index: Int) -> some View {
        VStack(spacing: 2) {
            Spacer()
            // Digit at center top
            Text(viewModel.digits[index])
                .font(Design.Font.regular(16))
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
            
            // Small underline inside box
            if viewModel.digits[index].isEmpty {
                Rectangle()
                    .frame(width: 11, height: 1)
                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
                    .padding(.horizontal, 8)
                Spacer().frame(height: 3)
            }
        }
        .padding(.all, 7)
        .frame(width: 27, height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 0.5)
                .stroke(Design.Color.navy, lineWidth: 1)
            
        )
    }

    @ViewBuilder
    private func backButton() -> some View {
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

    private func startTimer() {
        resendTimerCancellable?.cancel()

        resendTimer = 60
        timerRunning = true

        resendTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if resendTimer > 0 {
                    resendTimer -= 1
                } else {
                    timerRunning = false
                    resendTimerCancellable?.cancel()
                }
            }
    }

    private func observeVerification() {
        viewModel.$isVerified
            .removeDuplicates()
            .filter { $0 == true }
            .sink { _ in
                authViewModel.getStarted()
            }
            .store(in: &cancellables)
    }

    private func setupCallbacks() {
        viewModel.onAuthComplete = { authSession in
            if Storage.get(for: .userExist, type: .userDefaults, as: Bool.self) ?? false {
                authViewModel.updateSession(authSession)
                authViewModel.completeAuth()
            } else {
                authViewModel.step = .gettingStarted
            }
        }

        viewModel.onResendOTPComplete = { success in
            if success {
                startTimer()
            }
        }
    }
}
