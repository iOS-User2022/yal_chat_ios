//
//  GetStartedViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//


import Foundation
import Combine

final class GetStartedViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let userRepository: UserRepository
    private let authViewModel: AuthViewModel
    private var cancellables = Set<AnyCancellable>()
    var onStepChange: (() -> Void)?

    init(userRepository: UserRepository, authViewModel: AuthViewModel) {
        self.userRepository = userRepository
        self.authViewModel = authViewModel
    }

    // MARK: - Upload Profile Image (if needed)
    func updateProfileIfNeeded() {
        if let mobile = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self) {
            var updateRequest = UpdateProfileRequest()
            updateRequest.name = name
            updateRequest.mobile = mobile
            if updateRequest.toDictionary().isEmpty {
                //print("✅ No changes to update")
                return
            }
            
            LoaderManager.shared.show()
            
            userRepository.updateProfile(updateProfileRequest: updateRequest)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { result in
                    LoaderManager.shared.hide()
                    if case .failure(let error) = result {
                        print(error.localizedDescription)
                    }
                }, receiveValue: { [weak self] result in
                    LoaderManager.shared.hide()
                    switch result {
                    case .success:
                        //print("✅ Profile name updated successfully")
                        self?.onStepChange?()
                    case .unsuccess(let error):
                        print(error.localizedDescription)
                        self?.onStepChange?()
                    }
                })
                .store(in: &cancellables)
        }
    }
}
