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
            Design.Color.backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 139)
                
                Image("YAL Logo 1").frame(width: 40, height: 40)
                
                Spacer().frame(height: 24)

                headerSection()

                Spacer().frame(height: 24)

                countryPickerButton()

                Spacer().frame(height: 24)

                phoneInputFields()

                Spacer().frame(height: 48)

                getOtpButton().padding(.horizontal, 30)

                Spacer()
            }
            .padding(.horizontal, 30)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if isCountryDropdownOpen {
                countryDropdownPopup()
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
            Text("Please enter your country code and phone no.")
                .font(Design.Font.heavy(24))
                .foregroundColor(Design.Color.primaryTextColor)
                .multilineTextAlignment(.center)

            Text("YAL will send you an SMS to verify your phone number.")
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryTextColor.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func countryPickerButton() -> some View {
        HStack(spacing: 4) {

            // Small minus view
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isCountryDropdownOpen.toggle()
                }
            } label: {
                let imageName = viewModel.selectedCountry?.flag ?? ""
                Group {
                    if imageName.isEmpty {
                        // Show text when no image
                        Text("-")
                            .font(Design.Font.body)
                            .foregroundColor(Design.Color.secondryTextColor)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#202D35"))
                            .cornerRadius(6)
                    } else {
                        // Show image when available
                        Image(imageName) // ← NOT systemName
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#202D35"))
                            .cornerRadius(6)
                    }
                }
            }

            // Country picker button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isCountryDropdownOpen.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Text
                    Text(viewModel.selectedCountry?.name ?? "Select Country")
                        .font(Design.Font.body)
                        .foregroundColor(
                            viewModel.selectedCountry == nil
                            ? Design.Color.secondryTextColor
                            : Design.Color.primaryTextColor
                        )

                    Spacer()

                    // Chevron
                    Image(systemName: isCountryDropdownOpen ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(hex: "#202D35"))
                .cornerRadius(6)
            }
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
    }

    @ViewBuilder
    private func countryDropdownPopup() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: countryPickerFrame.minY) // Exactly aligned below the country picker field

            VStack(alignment: .leading, spacing: 0) {
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isCountryDropdownOpen.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("")
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#202D35"))
                            .clipShape(TopRoundedCorners(radius: 6))
                        HStack(spacing: 12) {
                            
                            // Text
                            Text("Select Country")
                                .font(Design.Font.body)
                                .foregroundColor(Design.Color.secondryTextColor)
                            
                            Spacer()
                            
                            // Chevron
                            Image(systemName: isCountryDropdownOpen ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white.opacity(0.8))
                            
                        }.frame(height: 44)
                        .padding(.horizontal, 16)
                        .background(Color(hex: "#202D35"))
                        .clipShape(TopRoundedCorners(radius: 6))
                    }
                }

                // Country List
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Country.allCountries) { country in
                            Button(action: {
                                viewModel.selectedCountry = country
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isCountryDropdownOpen = false
                                }
                            }) {
                                HStack(spacing: 4) {

                                    // Flag column
                                    ZStack{
                                        Text(" ")
                                            .foregroundColor(Design.Color.clear)
                                            .font(Design.Font.body)
                                        Image(country.flag)
                                            .scaledToFit()
                                            .frame(width: 44)
                                    }.padding(.vertical, 12)
                                        .background(Color(hex: "#202D35"))

                                    // Text content
                                    HStack {
                                        Text(country.name)
                                            .foregroundColor(Design.Color.primaryTextColor)
                                            .font(Design.Font.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)

                                        Text(country.dialCode)
                                            .foregroundColor(Design.Color.primaryTextColor)
                                            .font(Design.Font.body)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#202D35"))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .background(Design.Color.backgroundColor)
            .cornerRadius(6)
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            .transition(.scale.combined(with: .opacity))
        }.padding(.horizontal, 30)
    }

    @ViewBuilder
    private func phoneInputFields() -> some View {
        HStack(spacing: 4) {

            // Country code box
            HStack {
                Text(viewModel.selectedCountry?.dialCode ?? "-")
                    .font(Design.Font.body)
                    .foregroundColor( viewModel.selectedCountry?.dialCode == nil
                                      ? Design.Color.secondryTextColor
                                      : Design.Color.primaryTextColor)
            }
            .frame(width: 44, height: 44)
            .background(Color(hex: "#202D35"))
            .cornerRadius(6)

            // Phone number box
            HStack {
                TextField(
                    "",
                    text: $viewModel.phone,
                    prompt: Text("Phone no.")
                        .foregroundColor(Design.Color.secondryTextColor)
                        .font(Design.Font.body)
                )
                .keyboardType(.numberPad)
                .focused($isPhoneFocused)
                .font(Design.Font.body)
                .foregroundColor(Design.Color.primaryTextColor)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(hex: "#202D35"))
            .cornerRadius(6)
        }
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
                .foregroundColor(viewModel.isLoginEnabled ? .white : Design.Color.medium_gray)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        }
        .disabled(!viewModel.isLoginEnabled)
        .padding(.horizontal, 12.5)
        .background(
            viewModel.isLoginEnabled ? Design.Color.appGradient.opacity(1.0) : Design.Color.disabledGradient.opacity(1.0)
        )
        .cornerRadius(12)
    }
}

struct TopRoundedCorners: Shape {
    var radius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}
