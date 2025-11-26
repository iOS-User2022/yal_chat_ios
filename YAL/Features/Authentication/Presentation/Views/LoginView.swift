//
//  LoginView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: LoginViewModel
    @FocusState private var isPhoneFocused: Bool
    @State private var isCountryDropdownOpen = false
    @State private var countryPickerFrame: CGRect = .zero
    @State private var showAlert: Bool = false

    init() {
        let viewModel = DIContainer.shared.container.resolve(LoginViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Spacer().frame(height: 139)

                headerSection()

                Spacer().frame(height: 24)

                countryPickerButton()

                Spacer().frame(height: 24)

                phoneInputFields()

                Spacer().frame(height: 48)

                getOtpButton()

                Spacer()
            }
            .padding(.horizontal, 30)
            .background(Design.Color.white)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if isCountryDropdownOpen {
                countryDropdownPopup()
                    .padding(.horizontal, 52.5)
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            viewModel.onLoginSuccess = {
                authViewModel.step = .otpVerification(phone: viewModel.phoneWithCode)
            }
        }
        if showAlert, let alertModel = viewModel.alertModel {
            AlertView(model: alertModel) {
                showAlert = false
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection() -> some View {
        VStack(spacing: 12) {
            Text("Enter your phone number")
                .font(Design.Font.heavy(24))
                .foregroundColor(Design.Color.headingText)
                .multilineTextAlignment(.center)

            Text("YAL will send you an SMS message to verify your phone number.")
                .font(Design.Font.body)
                .foregroundColor(Design.Color.headingText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func countryPickerButton() -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCountryDropdownOpen.toggle()
            }
        }) {
            HStack(spacing: 12) {
                Spacer()
                if let imageName = viewModel.selectedCountry?.flag {
                    Image(imageName)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(viewModel.selectedCountry?.name ?? "Select country")
                    .foregroundColor(Design.Color.primaryText)
                    .font(Design.Font.body)
                Image(isCountryDropdownOpen ? "arrow-up" : "arrow-down")
                    .resizable()
                    .frame(width: 20, height: 20)
                Spacer()
            }
            .padding(.vertical, 12)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Design.Color.navy), alignment: .bottom)
        }
        .padding(.horizontal, 22.5)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        countryPickerFrame = geo.frame(in: .global)
                    }
                    .onChange(of: isCountryDropdownOpen) { _ in
                        countryPickerFrame = geo.frame(in: .global)
                    }
            }
        )
    }

    @ViewBuilder
    private func countryDropdownPopup() -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: countryPickerFrame.minY) // Exactly aligned below the country picker field

            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isCountryDropdownOpen.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        Spacer()
                        Text("Select country")
                            .font(Design.Font.body)
                            .foregroundColor(Design.Color.headingText)
                        Image("arrow-up")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                
                Rectangle()
                    .fill(Design.Color.navy.opacity(0.7))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Country List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Country.allCountries) { country in
                            Button(action: {
                                viewModel.selectedCountry = country
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isCountryDropdownOpen = false
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 32)
                                    Image(country.flag)
                                        .resizable()
                                        .frame(width: 18, height: 18)

                                    Text(country.name)
                                        .foregroundColor(Design.Color.primaryText)
                                        .font(Design.Font.body)

                                    Text(country.dialCode)
                                        .foregroundColor(Design.Color.primaryText)
                                        .font(Design.Font.body)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            
                            Rectangle()
                                .fill(Design.Color.navy.opacity(0.1))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial) // Native blurred background
                    .background(Color.white.opacity(0.3)) // Light white tint
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func phoneInputFields() -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Country code field
            VStack(alignment: .center, spacing: 8) {
                Text(viewModel.selectedCountry?.dialCode ?? "+00")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Color.primaryText)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Design.Color.navy)
            }
            .frame(width: 72, height: 38)

            // Phone number input field
            VStack(alignment: .center, spacing: 8) {
                // ONLY text field has padding
                TextField(
                    "",
                    text: $viewModel.phone,
                    prompt: Text("Phone number")
                        .foregroundColor(Design.Color.secondaryText.opacity(0.7))
                        .font(Design.Font.body)
                )
                .padding(.leading, 8) // padding only inside textfield
                .keyboardType(.numberPad)
                .focused($isPhoneFocused)
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryText)

                // Line without padding
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Design.Color.navy)
            }
            .frame(height: 38)
        }
        .padding(.horizontal, 22.5)
    }


    @ViewBuilder
    private func getOtpButton() -> some View {
        Button(action: {
            viewModel.login() {
                hideKeyboard()
                self.viewModel.showAlertForDeniedPermission()
                showAlert = true
            }
        }) {
            Text("Get OTP")
                .font(Design.Font.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        }
        .disabled(!viewModel.isLoginEnabled)
        .padding(.horizontal, 12.5)
        .background(
            viewModel.isLoginEnabled ? Design.Color.appGradient.opacity(1.0) : Design.Color.appGradient.opacity(0.6)
        )
        .cornerRadius(20)
    }
}
