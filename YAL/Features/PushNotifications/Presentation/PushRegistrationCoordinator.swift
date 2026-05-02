//
//  PushRegistrationCoordinator.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Combine

final class PushRegistrationCoordinator {
    private let registerUC: RegisterPusherUseCase
    private let unregisterUC: UnregisterPusherUseCase
    private let apnsStore: APNsTokenStore
    private let tokenProvider: TokenProvider
    private var bag = Set<AnyCancellable>()
    private var voipTokenStore: VoIPTokenStore
    
    init(registerUC: RegisterPusherUseCase,
         unregisterUC: UnregisterPusherUseCase,
         apnsStore: APNsTokenStore,
         tokenProvider: TokenProvider,
         voipTokenStore: VoIPTokenStore) {
        self.registerUC = registerUC
        self.unregisterUC = unregisterUC
        self.apnsStore = apnsStore
        self.tokenProvider = tokenProvider
        self.voipTokenStore = voipTokenStore
    }

    func start() {
        // Register when both: logged in + have token
        apnsStore.currentTokenHex
            .combineLatest(tokenProvider.matrixTokenPublisher) // AnyPublisher<String?, Never>
            .map { ($0, $1) }
            .removeDuplicates { lhs, rhs in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
            .sink { [weak self] tokenHex, access in
                guard let self = self else { return }
                guard let tokenHex, let access, !tokenHex.isEmpty, !access.isEmpty else { return }
                self.registerUC.execute(deviceTokenHex: tokenHex, type: .apns)
                    .sink(receiveCompletion: { _ in }, receiveValue: { })
                    .store(in: &self.bag)
            }
            .store(in: &bag)

        // Optional: on logout, unregister
        tokenProvider.logoutPublisher
            .compactMap { [weak self] _ in self?.apnsStore.lastKnownTokenHex }
            .flatMap { [unregisterUC] tokenHex in
                unregisterUC.execute(deviceTokenHex: tokenHex)
                    .catch { _ in Empty() } // ignore errors on logout
            }
            .sink { _ in }
            .store(in: &bag)
    }
    
    func voipStart() {
        // Register when both: logged in + have token
        voipTokenStore.currentTokenHex
            .combineLatest(tokenProvider.matrixTokenPublisher) // AnyPublisher<String?, Never>
            .map { ($0, $1) }
            .removeDuplicates { lhs, rhs in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
            .sink { [weak self] tokenHex, access in
                guard let self = self else { return }
                guard let tokenHex, let access, !tokenHex.isEmpty, !access.isEmpty else { return }
                self.registerUC.execute(deviceTokenHex: tokenHex, type: .voip)
                    .sink(receiveCompletion: { _ in }, receiveValue: { })
                    .store(in: &self.bag)
            }
            .store(in: &bag)
        
        // Optional: on logout, unregister
        tokenProvider.logoutPublisher
            .compactMap { [weak self] _ in self?.voipTokenStore.lastKnownTokenHex }
            .flatMap { [unregisterUC] tokenHex in
                unregisterUC.execute(deviceTokenHex: tokenHex)
                    .catch { _ in Empty() } // ignore errors on logout
            }
            .sink { _ in }
            .store(in: &bag)
    }
}
