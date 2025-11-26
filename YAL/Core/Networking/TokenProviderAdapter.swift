//
//  TokenProviderAdapter.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Combine

final class TokenProviderAdapter: TokenProvider {
    private let sessionProvider: AuthSessionProvider

    // NEW subjects for streams
    private let accessSubject = CurrentValueSubject<String?, Never>(nil)
    private let matrixSubject = CurrentValueSubject<String?, Never>(nil)
    private let logoutSubject = PassthroughSubject<Void, Never>()
    private var bag = Set<AnyCancellable>()

    init(sessionProvider: AuthSessionProvider) {
        self.sessionProvider = sessionProvider

        // Seed from current session
        push(sessionProvider.session)

        // Listen for future changes (login/restore/refresh/clear)
        sessionProvider.sessionPublisher
            .sink { [weak self] in self?.push($0) }
            .store(in: &bag)
    }

    // Snapshots (unchanged API)
    var accessToken: String? { sessionProvider.session?.accessToken }
    var matrixToken: String? { sessionProvider.session?.matrixToken }

    // Streams (NEW)
    var accessTokenPublisher: AnyPublisher<String?, Never> { accessSubject.eraseToAnyPublisher() }
    var matrixTokenPublisher: AnyPublisher<String?, Never> { matrixSubject.eraseToAnyPublisher() }
    var logoutPublisher: AnyPublisher<Void, Never> { logoutSubject.eraseToAnyPublisher() }

    func setToken(_ token: String) {
        guard let old = sessionProvider.session else { return }
        let updated = AuthSession(
            userId: old.userId,
            matrixToken: old.matrixToken,
            homeServer: old.homeServer,
            deviceId: old.deviceId,
            accessToken: token,
            refreshToken: old.refreshToken,
            matrixUrl: old.matrixUrl
        )
        sessionProvider.save(session: updated) // will trigger sessionPublisher → subjects
    }

    func clear() {
        sessionProvider.clear()  // will send nil via sessionPublisher
        logoutSubject.send(())   // explicit logout signal (handy for coordinators)
    }

    private func push(_ session: AuthSession?) {
        accessSubject.send(session?.accessToken)
        matrixSubject.send(session?.matrixToken)
        
        // Save Matrix token to App Group for notification extension
        if let token = session?.matrixToken {
            Storage.save(token, for: .matrixToken, type: .userDefaults)
            MediaDownloadHelper.saveToken(token)
        } else {
            MediaDownloadHelper.clearToken()
        }
    }
}
