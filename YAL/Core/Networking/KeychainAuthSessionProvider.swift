//
//  KeychainTokenProvider.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Combine

final class KeychainAuthSessionProvider: AuthSessionProvider {
    private let key: Storage.KeyType = .authSession
    
    // Backing subject seeded from Keychain once at init
    private let subject: CurrentValueSubject<AuthSession?, Never>
    
    init() {
        let existing = Storage.get(for: key, type: .keychain, as: AuthSession.self)
        self.subject = CurrentValueSubject<AuthSession?, Never>(existing)
    }
    
    // Snapshot
    var session: AuthSession? { subject.value }
    
    // Stream
    var sessionPublisher: AnyPublisher<AuthSession?, Never> { subject.eraseToAnyPublisher() }
    
    // Persist + publish
    func save(session: AuthSession) {
        Storage.save(session, for: key, type: .keychain)
        subject.send(session)
        Storage.save(session.matrixToken, for: .matrixToken, type: .userDefaults)
    }
    
    // Wipe + publish
    func clear() {
        Storage.delete(key, type: .keychain)
        subject.send(nil)
    }
}
