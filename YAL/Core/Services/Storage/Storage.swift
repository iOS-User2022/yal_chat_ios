//
//  StorageType.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Foundation

final class Storage {
    enum StorageType {
        case keychain, userDefaults, memory
    }

    enum KeyType: String {
        case mobileNumber
        case isLoggedIn
        case userExist
        case rememberMe
        case authSession
        case isFreshInstall
        case cachedProfile
        case syncResponse
        case contacts
        case spamProtectionStatus
        case contactSyncHash
        case roomsLoadedFromNetwork
        case recentsKey
        case isRoomDataSynced
        case favoriteRoomIDs
        case deletedRoomIDs
        case mutedRoomIDs
        case lockedRoomIDs
        case unreadRoomIDs
        case blockedRoomIDs
        case apnsToken
        case matrixToken
        case screenshotEnabled
        case isLockedChatsEnabled
        case lockSecurityOption
        case lockPin
        case autoLockOption
        case messagesLoadedFromNetwork
        case notificationContentType
    }

    // MARK: - Save

    static func save<T: Codable>(_ value: T, for key: KeyType, type: StorageType) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        switch type {
        case .keychain:
            KeychainService.shared.save(key: key.rawValue, value: data)
        case .userDefaults:
            UserDefaultsService.shared.save(key: key.rawValue, value: data)
        case .memory:
            InMemoryStorageService.shared.save(key: key.rawValue, value: data)
        }
    }

    // MARK: - Get

    static func get<T: Codable>(for key: KeyType, type: StorageType, as typeOf: T.Type) -> T? {
        let data: Data?

        switch type {
        case .keychain:
            data = KeychainService.shared.getData(key: key.rawValue)
        case .userDefaults:
            data = UserDefaultsService.shared.getData(key: key.rawValue)
        case .memory:
            data = InMemoryStorageService.shared.get(key: key.rawValue)
        }

        guard let data else { return nil }
        return try? JSONDecoder().decode(typeOf, from: data)
    }

    // MARK: - Delete

    static func delete(_ key: KeyType, type: StorageType) {
        switch type {
        case .keychain:
            KeychainService.shared.delete(key: key.rawValue)
        case .userDefaults:
            UserDefaultsService.shared.delete(key: key.rawValue)
        case .memory:
            InMemoryStorageService.shared.remove(key: key.rawValue)
        }
    }

    static func clearAll(type: StorageType) {
        switch type {
        case .keychain:
            KeychainService.shared.clearAll()
        case .userDefaults:
            UserDefaultsService.shared.clearAll()
        case .memory:
            InMemoryStorageService.shared.clearAll()
        }
    }
}

// MARK: - Private Keychain Implementation

private final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    func save(key: String, value: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        SecItemCopyMatching(query as CFDictionary, &item)
        return item as? Data
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clearAll() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Private UserDefaults Implementation

private final class UserDefaultsService {
    static let shared = UserDefaultsService()

    private let suiteName: String = "group.8S3YYR85J4.com.shared"

    private let defaults: UserDefaults

    private init() {
        // Create/attach to a dedicated persistent domain (separate plist file)
        guard let ud = UserDefaults(suiteName: suiteName) else {
            // As a fallback, create a fresh domain explicitly
            let ud = UserDefaults.standard
            ud.setPersistentDomain([:], forName: suiteName)
            self.defaults = UserDefaults(suiteName: suiteName) ?? ud
            return
        }
        self.defaults = ud
    }

    // MARK: - CRUD (scoped ONLY to this suite)
    func save(key: String, value: Data) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    func getData(key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func delete(key: String) {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
    }

    /// Clears ONLY this service's dedicated plist (not UserDefaults.standard).
    func clearAll() {
        // Most robust: drop the whole persistent domain for this suite.
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }
}

// MARK:- Private Inmemory Storage Implementation

final class InMemoryStorageService {
    static let shared = InMemoryStorageService()
    private init() {}

    private var storage: [String: Data] = [:]

    func save(key: String, value: Data) {
        storage[key] = value
    }

    func get(key: String) -> Data? {
        storage[key]
    }

    func remove(key: String) {
        storage.removeValue(forKey: key)
    }

    func clearAll() {
        storage.removeAll()
    }
}
