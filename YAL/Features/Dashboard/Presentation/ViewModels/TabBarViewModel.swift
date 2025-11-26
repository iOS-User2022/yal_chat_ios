//
//  TabBarViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/04/25.
//

import Combine
import Foundation

class TabBarViewModel: ObservableObject {
    private let router: Router
    private let userRepository: UserRepository
    private var cancellables = Set<AnyCancellable>()
    private let contactSyncCoordinator: ContactSyncCoordinator
    var syncCompletetd: (() -> Void)?
    
    @Published var contacts: [ContactLite] = []

    init(router: Router, userRepository: UserRepository, contactSyncCoordinator: ContactSyncCoordinator) {
        self.router = router
        self.contactSyncCoordinator = contactSyncCoordinator
        self.userRepository = userRepository
        observeContactStream()
    }

    private func observeContactStream() {
        contactSyncCoordinator.enrichedContactsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newContacts in
                self?.contacts = newContacts
                if let syncCompletetd = self?.syncCompletetd {
                    syncCompletetd()
                }
            }
            .store(in: &cancellables)
    }

    func startContactSync(syncCompletetd: @escaping () -> Void) {
        self.syncCompletetd = syncCompletetd
        ContactManager.shared.syncContacts()
    }

    func navigateToProfile() {
        router.currentRoute = .profile
    }

    func navigateToSettings() {
        router.currentRoute = .settings
    }

    func downloadProfile() {
        LoaderManager.shared.show()
        userRepository.getProfile()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("⚠️ Failed to refresh ProfileMenu:", error.localizedDescription)
                }
            }, receiveValue: { [weak self] result in
                LoaderManager.shared.hide()
                guard let self = self else { return }
                switch result {
                case .success(let profile):
                    self.saveProfileToStorage(profile)
                    print("✅ ProfileMenu refreshed successfully")
                case .unsuccess(let error):
                    print("⚠️ API unsuccessful in ProfileMenu:", error.localizedDescription)
                }
            })
            .store(in: &cancellables)
    }

    private func saveProfileToStorage(_ profile: ProfileResponse) {
        let editable = EditableProfile(
            mobile: Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self) ?? "",
            name: profile.name ?? "",
            email: profile.email ?? "",
            gender: profile.gender ?? "",
            dob: profile.dob?.formattedDateFromISO() ?? "",
            profession: profile.profession ?? "",
            about: profile.about ?? "",
            profileImageUrl: Endpoint.profileImageBasePath + (profile.profilePic ?? "")
        )
        Storage.save(editable, for: .cachedProfile, type: .userDefaults)
    }
}
