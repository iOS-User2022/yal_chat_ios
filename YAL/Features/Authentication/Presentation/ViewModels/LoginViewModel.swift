//
//  LoginViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Combine
import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var phone: String = ""
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var isOTPSent: Bool = false
    @Published var rememberMe: Bool = true
    @Published var selectedCountry: Country?
    @Published var countries: [Country] = Country.allCountries
    @Published var alertModel: AlertViewModel? = nil

    private let authRepository: AuthRepository
    private var cancellables = Set<AnyCancellable>()

    var phoneWithCode: String { (selectedCountry?.dialCode ?? "") + phone }
    var onLoginSuccess: (() -> Void)?
    var isLoginEnabled: Bool { !phone.isEmpty && selectedCountry != nil }
    
    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func login(completion: @escaping() -> Void) {
        LoaderManager.shared.show()
        authRepository.sendOtp(mobile: phoneWithCode)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] result in
                    switch result {
                    case .success(let response):
                        // Fetch previously saved mobile number
                        let previousMobile = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self)
                        let currentMobile = self?.phoneWithCode
                        
                        // Compare and delete all messages if mobile number has changed
                        if let previousMobile = previousMobile, previousMobile != currentMobile {
                            DBManager.shared.clearAllSync(purgeFiles: true)
                        }
                        Storage.save(response.exist, for: .userExist, type: .userDefaults)
                        Storage.save(self?.rememberMe, for: .rememberMe, type: .userDefaults)
                        Storage.save(self?.phoneWithCode, for: .mobileNumber, type: .userDefaults)
                        LoaderManager.shared.hide()
                        self?.onLoginSuccess?()
                    case .unsuccess(let error):
                        self?.errorMessage = error.localizedDescription
                        LoaderManager.shared.hide()
                        completion()
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
}
