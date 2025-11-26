//
//  OtpViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import Combine
import SwiftUI

class OtpViewModel: ObservableObject {
    @Published var digits: [String] = Array(repeating: "", count: 6)
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var isVerifying: Bool = false
    @Published var isVerified: Bool = false
    @Published var alertModel: AlertViewModel? = nil

    let phone: String
    var otp: String { digits.joined() }

    var onAuthComplete: ((AuthSession) -> Void)?
    var onResendOTPComplete: ((Bool) -> Void)?

    private let authRepository: AuthRepository
    private var cancellables = Set<AnyCancellable>()

    init(phone: String, authRepository: AuthRepository) {
        self.phone = phone
        self.authRepository = authRepository
    }

    var maskedPhone: String {
        let suffix = phone.suffix(4)
        return "******\(suffix)"
    }

    func verifyOtp(completion: @escaping() -> Void) {
        isVerifying = true
        LoaderManager.shared.show()

        authRepository.verifyOtp(phoneNumber: phone, otp: otp, deviceID: "your_real_device_id_here")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    LoaderManager.shared.hide()
                    self?.isVerifying = false

                    if case .failure(let error) = completion {
                        self?.showError = true
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    switch result {
                    case .success(let response):
                        self?.isVerifying = false
                        self?.isVerified = true
                        var matrixBaseUrl = ""
                        if let matrixUrl = response.matrixUrl {
                            matrixBaseUrl = "https://\(matrixUrl)"
                        }
                        self?.onAuthComplete?(AuthSession(
                            userId: response.userID,
                            matrixToken: response.accessToken,
                            homeServer: response.homeServer,
                            deviceId: response.deviceID,
                            accessToken: response.token,
                            refreshToken: response.refreshToken,
                            matrixUrl: matrixBaseUrl
                        ))
                    case .unsuccess(let apiError):
                        self?.showError = true
                        self?.errorMessage = apiError.localizedDescription
                        completion()
                    }
                }
            )
            .store(in: &cancellables)
    }

    func resendOTP() {
        LoaderManager.shared.show()
        authRepository.resendOtp(mobile: phone)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    LoaderManager.shared.hide()
                    if case .failure(let error) = completion {
                        self?.showError = true
                        self?.errorMessage = error.localizedDescription
                        self?.onResendOTPComplete?(false)
                    }
                },
                receiveValue: { [weak self] result in
                    switch result {
                    case .success:
                        self?.onResendOTPComplete?(true)
                    case .unsuccess(let error):
                        self?.showError = true
                        self?.errorMessage = error.localizedDescription
                        self?.onResendOTPComplete?(false)
                    }
                }
            )
            .store(in: &cancellables)
    }

    func showAlertForDeniedPermission() {
        alertModel = AlertViewModel(
            title: "Something Went Wrong",
            subTitle: "\(self.errorMessage)",
            actions: [
                AlertActionModel(title: "OK", style: .secondary, action: {})
            ]
        )
    }
    
    func clearOTP() {
        for i in 0..<digits.count {
            digits[i] = ""
        }
    }
}

