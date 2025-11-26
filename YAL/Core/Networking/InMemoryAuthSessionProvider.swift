//
//  InMemoryTokenProvider.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Foundation
import Combine

final class InMemoryAuthSessionProvider: AuthSessionProvider {
    // Backing subject (starts empty)
    private let subject = CurrentValueSubject<AuthSession?, Never>(nil)

    // Optional: allow seeding with a session (e.g., unit tests)
    init(initial: AuthSession? = nil) {
        subject.send(initial)
    }

    // Snapshot
    var session: AuthSession? { subject.value }

    // Stream
    var sessionPublisher: AnyPublisher<AuthSession?, Never> {
        subject.eraseToAnyPublisher()
    }

    // Persist (in-memory) + publish
    func save(session: AuthSession) {
        subject.send(session)
    }

    // Wipe + publish
    func clear() {
        subject.send(nil)
    }
}
