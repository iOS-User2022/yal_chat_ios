//
//  AuthViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var step: AuthStep = .login
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var phoneNumber: String = ""
    @Published private(set) var session: AuthSession?

    private let router: Router
    private let sessionProvider: AuthSessionProvider
    private var cancellables = Set<AnyCancellable>()

    init(
        router: Router,
        sessionProvider: AuthSessionProvider = DIContainer.shared.container.resolve(AuthSessionProvider.self)!
    ) {
        self.router = router
        self.sessionProvider = sessionProvider

        // Seed from provider (Keychain provider will already have a session if persisted)
        self.session = sessionProvider.session
        self.isLoggedIn = (sessionProvider.session?.accessToken.isEmpty == false)

        // React to future session changes (login/refresh/clear)
        sessionProvider.sessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSession in
                self?.session = newSession
                self?.isLoggedIn = (newSession?.accessToken.isEmpty == false)
            }
            .store(in: &cancellables)
    }

    // Save/update the active session (publishes to all subscribers, including TokenProviderAdapter)
    func updateSession(_ session: AuthSession) {
        self.session = session
        sessionProvider.save(session: session)
    }
    
    // MARK: - Step Navigation

    func initiateLogin() {
        router.currentRoute = .login
    }

    func showLogin() {
        step = .login
    }

    func showOtp(for phone: String) {
        phoneNumber = phone
        step = .otpVerification(phone: phone)
    }

    func getStarted() {
        step = .gettingStarted
    }

    func completeAuth() {
        isLoggedIn = true
        router.currentRoute = .dashboard
    }

    func checkLoginStatus() {
        if let session = sessionProvider.session, !session.accessToken.isEmpty {
            isLoggedIn = true
            router.currentRoute = .dashboard
        } else {
            isLoggedIn = false
            router.currentRoute = .onboarding
        }
    }

    func logout() {
        // Preserve mobile if you want
        let savedMobileNumber: String? = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self)

        // Publish "no session" so TokenProviderAdapter updates to nil tokens
        sessionProvider.clear()

        // Clear other app state
        Storage.clearAll(type: .userDefaults)
        if let mobile = savedMobileNumber {
            Storage.save(mobile, for: .mobileNumber, type: .userDefaults)
        }

        isLoggedIn = false
        step = .login
        router.currentRoute = .login
    }

    // MARK: - Auth API Integration
    func restorePreviousSession(_ session: UserSession) {
        completeAuth()
    }
}

enum AuthStep {
    case login
    case otpVerification(phone: String)
    case gettingStarted
    case completeAuth
}
