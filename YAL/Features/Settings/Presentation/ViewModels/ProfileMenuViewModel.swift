//
//  ProfileMenuViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/04/25.
//

import Combine
import SwiftUI

final class ProfileMenuViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var phone: String = ""
    @Published var imageURL: URL?

    private let userRepository: UserRepository
    private var cancellables = Set<AnyCancellable>()

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
        loadProfile()
        NotificationCenter.default.publisher(for: .profileDidUpdate)
            .sink { [weak self] _ in
                self?.refreshProfileFromStorage()
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Profile (from cache and silently refresh)
    func loadProfile() {
        if let cached = loadProfileFromStorage() {
            self.name = cached.name
            self.phone = cached.mobile
            if let urlString = cached.profileImageUrl, let url = URL(string: urlString) {
                self.imageURL = url
            }
            print("✅ Loaded ProfileMenu data from cache")
        }
        // Silent refresh
        downloadProfile()
    }

    // MARK: - Silent download
    private func downloadProfile() {
        userRepository.getProfile()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("⚠️ Failed to refresh ProfileMenu:", error.localizedDescription)
                }
            }, receiveValue: { [weak self] result in
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

    // MARK: - Cache Management
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
        print("proifile image saved priyanka")
    }

    private func loadProfileFromStorage() -> EditableProfile? {
        Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self)
    }
    
    private func refreshProfileFromStorage() {
        if let cached = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self) {
            self.name = cached.name
            self.phone = cached.mobile
            if let urlString = cached.profileImageUrl, let url = URL(string: urlString) {
                self.imageURL = url
            }
        }
    }
}

