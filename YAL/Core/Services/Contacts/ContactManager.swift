//
//  ContactManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/05/25.
//

import Contacts
import Foundation
import Combine
import PhoneNumberKit
import UIKit

// MARK: - Simple Contact Model for Notification Extension

struct SimpleContact: Codable {
    let userId: String?
    let displayName: String?
    let fullName: String?
}

enum ContactAccessStatus {
    case unknown
    case granted
    case denied
    case restricted
}

final class ContactManager {
    static let shared = ContactManager()
    private init() {
        // Clear caches automatically when the system sends a memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.clearCaches()
        }
    }

    // MARK: - Private properties
    private let phoneKit = PhoneNumberUtility()
    private let contactStore = CNContactStore()
    private var cancellables = Set<AnyCancellable>()
    let cacheQueue = DispatchQueue(label: "contacts.cache", attributes: .concurrent)

    // PassthroughSubjects (no value retention)
    private let contactsSubject = PassthroughSubject<[ContactLite], Never>()
    private let cacheContactsSubject = PassthroughSubject<[ContactLite], Never>()

    // Thread-safe cache of userId → ContactModel
    private var _contactCache: [String: ContactLite] = [:]
    private var _cachedContacts: [String: ContactModel] = [:]
    
    // MARK: - Public publishers
    @Published var accessStatus: ContactAccessStatus = .unknown

    var contactsPublisher: AnyPublisher<[ContactLite], Never> {
        contactsSubject.eraseToAnyPublisher()
    }

    var cacheContactsPublisher: AnyPublisher<[ContactLite], Never> {
        cacheContactsSubject.eraseToAnyPublisher()
    }

    func publishCachedContacts(_ contacts: [ContactLite]) {
        cacheContactsSubject.send(contacts)
    }
    
    // MARK: - Public cache accessors
    var contactCache: [String: ContactLite] {
        get {
            var snapshot: [String: ContactLite] = [:]
            cacheQueue.sync { snapshot = _contactCache }
            return snapshot
        }
        set {
            cacheQueue.async(flags: .barrier) { self._contactCache = newValue }
        }
    }

    var cachedContacts: [String: ContactModel] {
        get {
            var snapshot: [String: ContactModel] = [:]
            cacheQueue.sync { snapshot = _cachedContacts }
            return snapshot
        }
        set {
            cacheQueue.async(flags: .barrier) { self._cachedContacts = newValue }
        }
    }
    
    func clearCaches() {
        cacheQueue.async(flags: .barrier) {
            self._contactCache.removeAll()
        }
    }

    // MARK: - Sync logic
    func syncContacts() {
        if let cached = getStoredContacts(), !cached.isEmpty {
            cacheContactsSubject.send(cached)
            cacheContactsForNotifications(cached)
        }

        requestContactPermission()
            .flatMap { [weak self] granted -> AnyPublisher<[ContactLite], Never> in
                guard let self = self else { return Just([]).eraseToAnyPublisher() }
                guard granted else { return Just([]).eraseToAnyPublisher() }

                DispatchQueue.main.async { LoaderManager.shared.show() }
                return self.fetchContactsFromSystem()
            }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .handleEvents(receiveOutput: { contacts in
                if !contacts.isEmpty {
                    DBManager.shared.saveContacts(contacts: contacts)
                }
            })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contacts in
                guard let self else { return }
                if !contacts.isEmpty {
                    self.contactsSubject.send(contacts)
                    self.cacheContactsForNotifications(contacts)
                    LoaderManager.shared.hide()
                }
                LoaderManager.shared.hide()
            }
            .store(in: &cancellables)
    }

    // MARK: - Contact fetching
    private func fetchContactsFromSystem(
        defaultRegion: String = Locale.current.region?.identifier ?? "IN"
    ) -> AnyPublisher<[ContactLite], Never> {
        Future<[ContactLite], Never> { [weak self] promise in
            guard let self else { promise(.success([])); return }

            let keysToFetch: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactImageDataAvailableKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor // <-- full-res image data
            ]

            do {
                var result: [ContactLite] = []
                var seenE164 = Set<String>()
                let containers = try self.contactStore.containers(matching: nil)

                for container in containers {
                    let predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                    let contacts = try self.contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                    
                    let models: [ContactLite] = contacts.flatMap { contact in
                        contact.phoneNumbers.compactMap { labeled in
                            guard
                                let e164 = self.normalizeToE164(labeled.value.stringValue, defaultRegion: defaultRegion),
                                seenE164.insert(e164).inserted
                            else { return nil }
                            return ContactLite.from(contact: contact, phoneNumber: e164)
                        }
                    }
                    result.append(contentsOf: models)
                }

                promise(.success(result))
            } catch {
                promise(.success([]))
            }
        }
        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
        .eraseToAnyPublisher()
    }

    private func normalizeToE164(_ raw: String, defaultRegion: String) -> String? {
        let precleaned = raw
            .replacingOccurrences(of: "(?i)(ext|x)\\s*\\d+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        do {
            let parsed = try phoneKit.parse(precleaned, withRegion: defaultRegion, ignoreType: true)
            return phoneKit.format(parsed, toType: .e164)
        } catch {
            if precleaned.hasPrefix("00") {
                return "+" + String(precleaned.dropFirst(2))
            }
            return nil
        }
    }

    // MARK: - Permission handling
    private func requestContactPermission() -> Future<Bool, Never> {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        return Future { [weak self] promise in
            guard let self else { promise(.success(false)); return }

            func setStatus(_ s: ContactAccessStatus) {
                DispatchQueue.main.async { self.accessStatus = s }
            }

            switch status {
            case .authorized:
                setStatus(.granted)
                promise(.success(true))
            case .denied, .restricted:
                setStatus(.denied)
                promise(.success(false))
            case .notDetermined:
                PromptQueue.enqueue { done in
                    self.contactStore.requestAccess(for: .contacts) { granted, _ in
                        setStatus(granted ? .granted : .denied)
                        promise(.success(granted))
                        done()
                    }
                }
            case .limited:
                setStatus(.restricted)
                promise(.success(false))
            @unknown default:
                setStatus(.denied)
                promise(.success(false))
            }
        }
    }

    // MARK: - Storage / DB helpers
    private func getStoredContacts() -> [ContactLite]? {
        DBManager.shared.fetchContacts()
    }

    // MARK: - Public utilities
    func sendUpdatedContacts(contacts: [ContactLite]) {
        contactsSubject.send(contacts)
        cacheContactsForNotifications(contacts)
    }
    
    /// Cache contacts to shared UserDefaults for notification extension access
    private func cacheContactsForNotifications(_ contacts: [ContactLite]) {
        let simpleContacts = contacts.map { contact in
            SimpleContact(
                userId: contact.userId,
                displayName: contact.displayName,
                fullName: contact.fullName
            )
        }
        
        if let encoded = try? JSONEncoder().encode(simpleContacts),
           let sharedDefaults = UserDefaults(suiteName: "group.yalchat.shared") {
            sharedDefaults.set(encoded, forKey: "cached_contacts")
            sharedDefaults.synchronize()
        }
    }
    
    func contact(for userId: String) -> ContactLite? {
        guard !userId.isEmpty else { return nil }

        var cached: ContactLite?
        cacheQueue.sync { cached = _contactCache[userId] }
        if let cached { return cached }

        if let dbContact = DBManager.shared.fetchContact(userId: userId) {
            cacheQueue.async(flags: .barrier) {
                self._contactCache[userId] = dbContact
            }
            return dbContact
        }
        return nil
    }
    
    func contactModel(for userId: String) -> ContactModel? {
        guard !userId.isEmpty else { return nil }
        
        var cached: ContactModel?
        cacheQueue.sync { cached = _cachedContacts[userId] }
        if let cached { return cached }
        
        if let liteContact = contact(for: userId) {
            let contactModel = ContactModel.fromLite(liteContact)
            cacheQueue.async(flags: .barrier) {
                self._cachedContacts[userId] = contactModel
            }
        }
        return nil
    }
    
    @discardableResult
    func updatePresence(
        for userId: String,
        isOnline: Bool,
        lastSeen: Int?,
        avatarURL: String? = nil,
        statusMessage: String? = nil
    ) -> ContactModel? {
        guard !userId.isEmpty else { return nil }
        
        var lite  = contact(for: userId) ?? ContactLite(userId: userId, fullName: "", phoneNumber: "")
        let model = contactModel(for: userId) ?? ContactModel.fromLite(lite)
        
        lite.updatePresence(isOnline: isOnline, lastSeen: lastSeen, avatarURL: avatarURL, statusMessage: statusMessage)
        model.updatePresence(isOnline: isOnline, lastSeen: lastSeen, avatarURL: avatarURL, statusMessage: statusMessage)
        
        cacheQueue.async(flags: .barrier) {
            self._contactCache[userId]  = lite
            self._cachedContacts[userId] = model
        }
        
         DBManager.shared.upsertContactPresence(
            userId: userId,
            currentlyActive: isOnline,
            lastActiveAgoMs: lastSeen,
            avatarURL: avatarURL,
            statusMessage: statusMessage
         )
        
        return model
    }
}

extension ContactManager {
    
    func primeCache(with dbContacts: [ContactLite]) {
        // keep only real users (userId present)
        let users = dbContacts.filter {
            if let id = $0.userId?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return !id.isEmpty
            }
            return false
        }
        guard !users.isEmpty else { return }
        
        updateMemoryCaches(for: users)
    }
    
    func updateMemoryCaches(for contacts: [ContactLite]) {
        guard !contacts.isEmpty else { return }

        var liteById: [String: ContactLite] = [:]
        var modelById: [String: ContactModel] = [:]
        liteById.reserveCapacity(contacts.count)
        modelById.reserveCapacity(contacts.count)

        for c in contacts {
            guard let uid = c.userId, !uid.isEmpty else { continue }
            liteById[uid] = c
            modelById[uid] = ContactModel.fromLite(c) // your existing converter
        }
        guard !liteById.isEmpty else { return }

        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            for (uid, incoming) in liteById {
                if let existing = self._contactCache[uid] {
                    self._contactCache[uid] = self.mergeLite(existing, with: incoming)
                } else {
                    self._contactCache[uid] = incoming
                }
            }

            for (uid, incomingModel) in modelById {
                if let existingModel = self._cachedContacts[uid] {
                    self.mergeModelInPlace(existingModel, with: incomingModel)
                } else {
                    self._cachedContacts[uid] = incomingModel
                }
            }
        }
    }

    func updateMemoryCaches(for contact: ContactLite) {
        updateMemoryCaches(for: [contact])
    }


    private func mergeLite(_ old: ContactLite, with new: ContactLite) -> ContactLite {
        var out = old

        if (out.userId ?? "").isEmpty, let uid = new.userId, !uid.isEmpty { out.userId = uid }
        if out.phoneNumber.isEmpty, !new.phoneNumber.isEmpty { out.phoneNumber = new.phoneNumber }

        if let v = new.fullName, !v.isEmpty { out.fullName = v }
        if let v = new.displayName, !v.isEmpty { out.displayName = v }
        if let v = new.avatarURL, !v.isEmpty { out.avatarURL = v }
        if let v = new.imageURL, !v.isEmpty { out.imageURL = v }
        if let v = new.about, !v.isEmpty { out.about = v }
        if let v = new.gender { out.gender = v }
        if let v = new.profession { out.profession = v }
        if let v = new.dob { out.dob = v }

        out.isOnline = new.isOnline
        if let lastSeen = new.lastSeen { out.lastSeen = lastSeen }

        if !new.emailAddresses.isEmpty {
            out.emailAddresses = new.emailAddresses
        }

        out.isBlocked = new.isBlocked
        out.isSynced = out.isSynced || new.isSynced

        return out
    }

    private func mergeModelInPlace(_ dst: ContactModel, with src: ContactModel) {
        if let fullName = src.fullName, !fullName.isEmpty, dst.fullName != fullName { dst.fullName = fullName }
        if dst.phoneNumber != src.phoneNumber, !src.phoneNumber.isEmpty { dst.phoneNumber = src.phoneNumber }
        if let uid = src.userId, !uid.isEmpty, dst.userId != uid { dst.setUserId(uid) }

        if let dn = src.displayName, !dn.isEmpty { dst.setDisplayName(displayName: dn) }
        if let imgURL = src.imageURL, !imgURL.isEmpty { dst.setImageURL(imageURL: imgURL) }
        if let avatar = src.avatarURL, !avatar.isEmpty { dst.setAvatarURL(avatarURL: avatar) }
        if let status = src.statusMessage, !status.isEmpty { dst.setStatusMessage(statusMessage: status) }
        if let gender = src.gender { dst.gender = gender }
        if let profession = src.profession { dst.profession = profession }
        if let dob = src.dob { dst.dob = dob }

        // Presence
        dst.setIsOnline(isOnline: src.isOnline)
        if let ls = src.lastSeen { dst.setLastSeen(lastSeen: ls) }

        // Emails
        if !src.emailAddresses.isEmpty { dst.emailAddresses = src.emailAddresses }

        // Binary/image data — prefer incoming if present
        if let data = src.imageData, !data.isEmpty { dst.imageData = data }

        // Flags
        dst.isBlocked = dst.isBlocked || src.isBlocked
        dst.isSynced  = dst.isSynced  || src.isSynced
    }
}
