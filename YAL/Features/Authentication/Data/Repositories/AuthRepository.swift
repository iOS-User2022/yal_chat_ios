//
//  AuthRepository.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/04/25.
//


import Combine

final class AuthRepository {
    private let apiManager: ApiManageable

    init(apiManager: ApiManageable) {
        self.apiManager = apiManager
    }

    func sendOtp(mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError> {
        apiManager.otpLogin(with: mobile)
    }

    func resendOtp(mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError> {
        apiManager.resentOTP(with: mobile)
    }

    func verifyOtp(phoneNumber: String, otp: String, deviceID: String) -> AnyPublisher<APIResult<OTPResponse>, APIError> {
        apiManager.verify(phoneNumber: phoneNumber, otp: otp, deviceID: deviceID)
    }

    func fetchProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError> {
        apiManager.getProfile()
    }
}
