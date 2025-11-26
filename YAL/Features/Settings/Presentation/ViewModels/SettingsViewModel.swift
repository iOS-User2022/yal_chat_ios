//
//  SettingsViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var settings: [(String, Image?, Color)] = []
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false
    @Published var isAccountDeleted: Bool = false
    @Published var isLoading: Bool = false
    private let dbManager: DBManageable
    private let apiManager: ApiManageable
    private let router: Router
    private var cancellables = Set<AnyCancellable>()

    init(
        dbManager: DBManageable,
        apiManager: ApiManageable,
        router: Router
    ) {
        self.dbManager = dbManager
        self.apiManager = apiManager
        self.router = router

        self.settings = [
            ("Logout", Image(systemName: "rectangle.portrait.and.arrow.right"), .black),
            ("Delete Account", Image(systemName: "trash"), .red)
        ]
    }

    func deleteAccount() {
        isLoading = true

        apiManager.deleteProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    Storage.clearAll(type: .userDefaults)
                    Storage.clearAll(type: .keychain)
                    self.isLoading = false

                    if case .failure = completion {
                        self.alertMessage = "Something went wrong"
                        self.isAccountDeleted = false
                        self.showAlert = true
                    }
                },
                receiveValue: { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success:
                        self.alertMessage = "Account deleted successfully"
                        self.isAccountDeleted = true
                    case .unsuccess:
                        self.alertMessage = "Something went wrong"
                        self.isAccountDeleted = false
                    }

                    self.showAlert = true
                }
            )
            .store(in: &cancellables)
    }

}
