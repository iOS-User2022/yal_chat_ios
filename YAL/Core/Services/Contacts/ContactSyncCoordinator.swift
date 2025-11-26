//
//  ContactSyncCoordinator.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/05/25.
//


import Foundation
import Combine
import RealmSwift

final class ContactSyncCoordinator {
    private let enrichedSubject = CurrentValueSubject<[ContactLite], Never>([])
    var enrichedContactsPublisher: AnyPublisher<[ContactLite], Never> {
        enrichedSubject.eraseToAnyPublisher()
    }
    
    private var _lastSyncedHash: String?
    
    private var lastSyncedHash: String? {
        get { _lastSyncedHash ?? Storage.get(for: .contactSyncHash, type: .userDefaults, as: String.self) }
        set {
            _lastSyncedHash = newValue
            if let hash = newValue {
                Storage.save(hash, for: .contactSyncHash, type: .userDefaults)
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let userRepository: UserRepository?
    private let cacheQueue = DispatchQueue(label: "contacts.cache", attributes: .concurrent)
    private var contactToken: NotificationToken?

    deinit { contactToken?.invalidate() }
    
    init(userRepository: UserRepository) {
        self.userRepository = userRepository
        self.observeContacts()

        ContactManager.shared.contactsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rawContacts in
                ContactManager.shared.contactCache.removeAll()
                self?.enrichContactsWithUserIds(rawContacts)
            }
            .store(in: &cancellables)
        
        ContactManager.shared.cacheContactsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cachedContacts in
                self?.enrichedSubject.send(cachedContacts)
            }
            .store(in: &cancellables)
    }
    
    private func cacheKey(for contact: ContactObject) -> String? {
        if let uid = contact.userId?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
            return uid.lowercased()
        }
        return nil
    }
    
    private func enrichContactsWithUserIds(_ contacts: [ContactLite]) {
        let hash = stableContactsHash(contacts)
        if let lastHash = lastSyncedHash, hash == lastHash { return }

        let phoneNumbers = contacts.map { $0.phoneNumber.filter { !$0.isWhitespace } }

        DispatchQueue.main.async { LoaderManager.shared.show() } // UI on main

        userRepository?.getMatrixUsers(phoneNumbers: phoneNumbers)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated)) // heavy off-main
            .tryMap { [weak self] response -> [ContactLite] in
                guard let self else { return contacts }
                switch response {
                case .success(let mapping):
                    var enriched = contacts
                    for user in mapping.data {
                        if let i = enriched.firstIndex(where: { $0.phoneNumber == user.phone }) {
                            enriched[i].setUserId(user.userId)
                        }
                    }
                    DBManager.shared.saveContacts(contacts: enriched)
                    self.lastSyncedHash = hash
                    return enriched
                case .unsuccess(let err):
                    throw err
                }
            }
            .receive(on: DispatchQueue.main) // UI on main
            .sink(
                receiveCompletion: { completion in
                    LoaderManager.shared.hide()
                    if case .failure(let error) = completion {
                        if let apiError = error as? APIError {
                            print("Enrichment failure: \(apiError)")
                        } else {
                            print("Enrichment failure: \(error.localizedDescription)")
                        }
                    } else {
                        print("Enrichment success")
                    }
                },
                receiveValue: { [weak self] enriched in
                    self?.warmContactsCacheIfNeeded(enriched: enriched)
                    self?.enrichedSubject.send(enriched)
                    self?.fetchProfilesIfNeeded(for: enriched)
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchProfilesIfNeeded(for contacts: [ContactLite]) {
        // Only contacts that already have userId and are not yet synced
        let ids = Array(Set(contacts.compactMap { c -> String? in
            guard let uid = c.userId, !uid.isEmpty, !c.isSynced else { return nil }
            return uid
        }))
        guard !ids.isEmpty else { return }

        userRepository?.getUserProfiles(userIds: ids)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let e) = completion {
                        print("fetchProfilesIfNeeded failed: \(e)")
                    }
                },
                receiveValue: { [weak self] profiles in
                    guard let self else { return }

                    let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userID, $0) })

                    let updated: [ContactLite] = contacts.map { c in
                        guard let uid = c.userId, let profile = byId[uid] else { return c }
                        var out = c
                        if let displayName = profile.name, !displayName.isEmpty { out.displayName = displayName }
                        if let av = profile.mxcProfile, !av.isEmpty { out.avatarURL = av }
                        if let gender = profile.gender { out.gender = gender }
                        if let profession = profile.profession { out.profession = profession }
                        if let status = profile.about { out.about = status }
                        if let dob = profile.dob { out.dob = dob }
                        if let email = profile.email, !email.isEmpty { out.emailAddresses = [email] }
                        out.isSynced = true
                        return out
                    }

                    // Persist & refresh caches
                    DBManager.shared.saveContacts(contacts: contacts)
                    ContactManager.shared.updateMemoryCaches(for: updated)
                    self.enrichedSubject.send(updated)
                }
            )
            .store(in: &cancellables)
    }
    
    private func warmContactsCacheIfNeeded(enriched: [ContactLite]) {
        var alreadyWarm = false
        cacheQueue.sync { alreadyWarm = !ContactManager.shared.contactCache.isEmpty }
        guard !alreadyWarm else { return }

        let pairs: [(String, ContactLite)] = enriched.compactMap { contact in
            let raw = (contact.userId as String?).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let id = raw, !id.isEmpty else { return nil }

            let key = id.lowercased()
            return (key, contact)
        }

        // Build dictionary without crashing on duplicate keys
        // Choose merge policy: here "last write wins"
        let dict = Dictionary(pairs, uniquingKeysWith: { _, new in new })

        cacheQueue.async(flags: .barrier) {
            ContactManager.shared.contactCache = dict
        }
    }
    
    func observeContacts() {
        contactToken?.invalidate()

        let realm = DBManager.shared.realm
        let results = realm.objects(ContactObject.self)
            .sorted(byKeyPath: "phoneNumber", ascending: true)

        contactToken = results.observe { [weak self] changes in
            guard let self else { return }

            switch changes {
            case .initial(let collection),
                 .update(let collection, _, _, _):
                self.updateSharedCache(from: collection)

            case .error(let error):
                print("Realm contact observation error: \(error)")
            }
        }
    }
    
    private func updateSharedCache(from results: Results<ContactObject>) {
        var oldCache: [String: ContactLite] = [:]
        ContactManager.shared.cacheQueue.sync {
            oldCache = ContactManager.shared.contactCache
        }

        var newCache = oldCache
        var models: [ContactLite] = []
        models.reserveCapacity(results.count)

        for object in results {
            if let model = upsertContact(from: object, into: &newCache) {
                models.append(model)
            }
        }

        let validKeys = Set(results.map(cacheKey(for:)))
        for key in newCache.keys where !validKeys.contains(key) {
            newCache.removeValue(forKey: key)
        }

        ContactManager.shared.cacheQueue.async(flags: .barrier) {
            ContactManager.shared.contactCache = newCache
            DispatchQueue.main.async {
                ContactManager.shared.publishCachedContacts(models)
                self.enrichedSubject.send(models)
            }
        }
    }
    
    private func upsertContact(
        from object: ContactObject,
        into cache: inout [String: ContactLite]
    ) -> ContactLite? {
        if let key = cacheKey(for: object) {
            if var existing = cache[key] {
                // Update on main so @Published triggers UI updates
                if let fullName = object.fullName, !fullName.isEmpty, existing.fullName != fullName {
                    existing.fullName = fullName
                }
                if existing.phoneNumber != object.phoneNumber {
                    existing.phoneNumber = object.phoneNumber
                }
                if let userId = object.userId, !userId.isEmpty, existing.userId != userId {
                    existing.userId = userId.formattedMatrixUserId
                }
                if let avatarURL = object.avatarURL, !avatarURL.isEmpty, existing.avatarURL != avatarURL {
                    existing.avatarURL = avatarURL
                }
                if let about = object.statusMessage, !about.isEmpty, existing.about != about {
                    existing.about = about
                }
                if let gender = object.gender, !gender.isEmpty, existing.gender != gender {
                    existing.gender = gender
                }
                if  let profession = object.profession, !profession.isEmpty, existing.profession != profession {
                    existing.profession = profession
                }
                if let dob = object.dob, !dob.isEmpty, existing.dob != dob {
                    existing.dob = dob
                }
                if let emailData = object.emailData, !emailData.isEmpty {
                    do {
                        let decodedEmails = try JSONDecoder().decode([String].self, from: emailData)
                        if existing.emailAddresses != decodedEmails {
                            existing.emailAddresses = decodedEmails
                        }
                    } catch {
                        print("Failed to decode emailData for contact \(object.phoneNumber): \(error)")
                    }
                }
                return existing
            } else {
                // New model instance
                var emails = [String]()
                do  {
                    emails = try JSONDecoder().decode([String].self, from: object.emailData ?? Data([]))
                } catch {
                    print("Failed to decode emailData for contact \(object.phoneNumber): \(error)")
                }
                
                let new = ContactLite(
                    userId: key,
                    fullName: object.fullName ?? "",
                    phoneNumber: object.phoneNumber,
                    emailAddresses: emails,
                    imageURL: object.avatarURL,
                    avatarURL: object.avatarURL,
                    displayName: object.displayName,
                    about: object.statusMessage,
                    dob: object.dob,
                    gender: object.gender,
                    profession: object.profession,
                    isBlocked: false,
                    isSynced: false,
                    isOnline: false,
                    lastSeen: nil
                )
                cache[key] = new
                return new
            }
        }
        return nil
    }
}
