//
//  ProfileViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import Combine

struct EditableProfile: Codable {
    var mobile: String
    var name: String
    var email: String
    var gender: String
    var dob: String
    var profession: String
    var about: String
    var profileImageUrl: String?
}

class ProfileViewModel: ObservableObject {
    @Published var originalProfile: EditableProfile?
    @Published var editableProfile: EditableProfile?
    @Published var showProfileRefreshError: Bool = false
    @Published var alertModel: AlertViewModel? = nil

    // MARK: - Dependencies
    private let userRepository: UserRepository
    private let router: Router
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init(userRepository: UserRepository, router: Router) {
        self.userRepository = userRepository
        self.router = router
    }
    
    // MARK: - OnAppear Load
    func loadProfile() {
        // Try to load cached data first
        if let cached = loadProfileFromStorage() {
            self.originalProfile = cached
            self.editableProfile = cached
            print("✅ Loaded profile from cache")
        }
        
        // Silent API call to refresh
        downloadProfile()
    }
    
    // MARK: - API Call
    func downloadProfile() {
        userRepository.getProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(_) = completion {
                        print("⚠️ Failed to refresh profile")
                        self?.showProfileRefreshError = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.showProfileRefreshError = false
                        }
                    }
                },
                receiveValue: { [weak self] result in
                    switch result {
                    case .success(let response):
                        let editable = self?.convertToEditableProfile(response)
                        self?.originalProfile = editable
                        self?.editableProfile = editable
                        if let editable {
                            self?.saveProfileToStorage(editable)
                        }
                        print("✅ Profile refreshed successfully")
                    case .unsuccess(let error):
                        print("⚠️ API unsuccessful:", error.localizedDescription)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Upload Profile (if needed)
    func updateProfileIfNeeded(completion: @escaping(_ success: Bool) -> Void) {
        guard let original = originalProfile,
              let edited = editableProfile else { return }
        
        var updateRequest = UpdateProfileRequest()
        
        if original.mobile != edited.mobile { updateRequest.mobile = edited.mobile }
        if original.name != edited.name { updateRequest.name = edited.name }
        if original.email != edited.email { updateRequest.email = edited.email }
        if original.gender != edited.gender { updateRequest.gender = edited.gender }
        if original.dob != edited.dob { updateRequest.dob = edited.dob }
        if original.profession != edited.profession { updateRequest.profession = edited.profession }
        if original.about != edited.about { updateRequest.about = edited.about }
        if original.profileImageUrl != edited.profileImageUrl { updateRequest.mxcProfile = edited.profileImageUrl }
        
        if updateRequest.toDictionary().isEmpty {
            print("✅ No changes to update")
            return
        }
        
        LoaderManager.shared.show()
        
        userRepository.updateProfile(updateProfileRequest: updateRequest)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                LoaderManager.shared.hide()
                if case .failure(let error) = result {
                    print(error.localizedDescription)
                }
            }, receiveValue: { [weak self] result in
                LoaderManager.shared.hide()
                switch result {
                case .success:
                    self?.originalProfile = self?.editableProfile
                    if let profile = self?.editableProfile {
                        self?.saveProfileToStorage(profile)
                    }
                    completion(true)
                    print("✅ Profile updated successfully", result.self)
                case .unsuccess(let error):
                    completion(false)
                    print(error.localizedDescription)
                }
            })
            .store(in: &cancellables)
    }
    
    func showAlertForDeniedPermission(success: Bool) {
        var title = "Profile Updated Successfully"
        var subTitle = "Your changes have been saved and updated."
        var image = "tick-circle-green"
        if !success {
             title = "Profile Update Failed"
             subTitle = "An error occurred while saving your changes."
             image = "cancel"
        }
        alertModel = AlertViewModel(
            title: title,
            subTitle: subTitle,
            imageName: image,
            actions: [
                AlertActionModel(title: "OK", style: .secondary, action: {})
            ]
        )
    }
    
    // MARK: - Helpers
    
    private func saveProfileToStorage(_ profile: EditableProfile) {
        Storage.save(profile, for: .cachedProfile, type: .userDefaults)
        NotificationCenter.default.post(name: .profileDidUpdate, object: nil)
    }
    
    private func loadProfileFromStorage() -> EditableProfile? {
        return Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self)
    }
    
    private func convertToEditableProfile(_ response: ProfileResponse) -> EditableProfile {
        return EditableProfile(
            mobile: Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self) ?? "",
            name: response.name ?? "",
            email: response.email ?? "",
            gender: response.gender ?? "",
            dob: response.dob?.formattedDateFromISO() ?? "",
            profession: response.profession ?? "",
            about: response.about ?? "",
            profileImageUrl: response.mxcProfile ?? ""
        )
    }
}
