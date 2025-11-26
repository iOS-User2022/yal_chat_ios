//
//  ProfileSyncCoordinator.swift
//  YAL
//
//  Created by Vishal Bhadade on 14/10/25.
//


import Combine
import Foundation

final class ProfileSyncCoordinator {
    private let userRepository: UserRepository
    private let queue = DispatchQueue(label: "profilesync.coordinator", qos: .utility)
    private var bag = Set<AnyCancellable>()
    
    // Input pipe
    private let idSubject = PassthroughSubject<[String], Never>()
    
    // Config
    private let debounceMs: Int
    private let batchSize: Int
    private let maxParallelBatches: Int
    
    init(
        userRepository: UserRepository,
        debounceMs: Int = 300,
        batchSize: Int = 50,
        maxParallelBatches: Int = 2
    ) {
        self.userRepository = userRepository
        self.debounceMs = debounceMs
        self.batchSize = batchSize
        self.maxParallelBatches = maxParallelBatches
        
        wire()
    }
    
    /// Public: enqueue any number of userIds (duplicates ok).
    func enqueue(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        idSubject.send(ids)
    }
    
    private func wire() {
        idSubject
            .receive(on: queue)
            .collect(.byTime(queue, .milliseconds(debounceMs)))
            .map { Array(Set($0.flatMap { $0 })) }               // dedupe window
            .flatMap { [weak self] ids -> AnyPublisher<[ProfileResponse], Never> in
                guard let self, !ids.isEmpty else { return Just([]).eraseToAnyPublisher() }

                let batches = stride(from: 0, to: ids.count, by: self.batchSize)
                    .map { Array(ids[$0 ..< min($0 + self.batchSize, ids.count)]) }

                return Publishers.Sequence(sequence: batches)
                    .flatMap(maxPublishers: .max(self.maxParallelBatches)) { batch in
                        self.userRepository.getUserProfiles(userIds: batch)
                            .replaceError(with: [])               // never fail stream
                    }
                    .collect()
                    .map { $0.flatMap { $0 } }                    // [[Profile]] -> [Profile]
                    .eraseToAnyPublisher()
            }
            .receive(on: queue)                                   // keep processing off-main
            .sink { profiles in
                guard !profiles.isEmpty else { return }
                Self.applyProfiles(profiles)                      // thread-safe (see below)
            }
            .store(in: &bag)
    }
    
    private static func applyProfiles(_ profiles: [ProfileResponse]) {
        guard !profiles.isEmpty else { return }

        // Build a map once to avoid repeatedly scanning
        let byId: [String: ProfileResponse] =
            Dictionary(profiles.compactMap { profile in
                guard let id = profile.userID, !id.isEmpty else { return nil }
                return (id, profile)
            }) { _, new in new }

        // Batch update Realm in an autoreleasepool to keep peak memory low
        autoreleasepool {
            var toUpdate: [ContactLite] = []
            var toInsert: [ContactLite] = []

            for (userId, profile) in byId {
                let formattedUserId = userId.formattedMatrixUserId
                if var c = ContactManager.shared.contact(for: formattedUserId) {
                    c.userId = formattedUserId
                    c.phoneNumber = profile.phone ?? ""
                    c.displayName = profile.name
                    c.emailAddresses = profile.email.map { [$0] } ?? []
                    c.imageURL = profile.profilePic
                    c.about = profile.about
                    c.dob = profile.dob
                    c.gender = profile.gender
                    c.profession = profile.profession
                    c.isSynced = true
                    toUpdate.append(c)
                } else {
                    let contact = ContactLite(
                        userId: formattedUserId,
                        fullName: "",
                        phoneNumber: profile.phone ?? "",
                        emailAddresses: profile.email.map { [$0] } ?? [],
                        imageURL: profile.mxcProfile,
                        avatarURL: profile.mxcProfile,
                        displayName: profile.name,
                        about: profile.about,
                        dob: profile.dob,
                        gender: profile.gender,
                        profession: profile.profession,
                        isBlocked: false,
                        isSynced: false,
                        isOnline: false,
                        lastSeen: nil,
                    )
                    toInsert.append(contact)
                }
            }

            if !toUpdate.isEmpty { DBManager.shared.saveContacts(contacts: toUpdate) }
            if !toInsert.isEmpty { DBManager.shared.saveContacts(contacts: toInsert) }
        }

        // Notify on main for UI safety
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didSyncProfiles, object: Set(byId.keys))
        }
    }
}

extension Notification.Name {
    static let didSyncProfiles = Notification.Name("didSyncProfiles")
}
