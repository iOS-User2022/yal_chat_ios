//
//  APNsTokenStore.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Foundation
import Combine

// Holds the latest APNs device token (as lowercase hex) and publishes changes.
// Persists to UserDefaults so it survives app restarts.
final class APNsTokenStore {
    private let subject: CurrentValueSubject<String?, Never>
    private let queue = DispatchQueue(label: "APNsTokenStore.queue", qos: .userInitiated)

    // Stream of current APNs token hex (or nil until available)
    var currentTokenHex: AnyPublisher<String?, Never> { subject.eraseToAnyPublisher() }

    // Convenience accessor for the last value
    var lastKnownTokenHex: String? { subject.value }

    init() {
        let stored = Storage.get(for: .apnsToken, type: .userDefaults, as: String.self)
        self.subject = CurrentValueSubject<String?, Never>(stored)
    }

    // Update from APNs callback
    func update(deviceToken: Data) {
        update(hexString: deviceToken.hexStringLowercased())
    }

    // Update with a known-hex string (handy for tests)
    func update(hexString: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.subject.value != hexString else { return } // de-dupe
            Storage.save(hexString, for: .apnsToken, type: .userDefaults)
            DispatchQueue.main.async { self.subject.send(hexString) }
        }
    }

    // Clear token (e.g., on uninstall logic / wipe)
    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            Storage.delete(.apnsToken, type: .userDefaults)
            DispatchQueue.main.async { self.subject.send(nil) }
        }
    }

    // Re-send current value to listeners (useful after DI wiring)
    func rebroadcast() { subject.send(subject.value) }
}

private extension Data {
    func hexStringLowercased() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
