//
//  UserRepository.swift
//  YAL
//
//  Created by Vishal Bhadade on 22/04/25.
//


import Combine
import Foundation

final class UserRepository {
    private let apiManager: ApiManageable

    init(apiManager: ApiManageable) {
        self.apiManager = apiManager
    }

    /// Fetches the logged-in user's profile.
    func getProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError> {
        apiManager.getProfile()
    }

    /// Updates the user's profile with provided name and email.
    func updateProfile(updateProfileRequest: UpdateProfileRequest) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        apiManager.updateProfile(updateProfileRequest: updateProfileRequest)
    }
    
    /// Deletes the user's profile.
    func deleteProfile() -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        apiManager.deleteProfile()
    }

    /// Uploads a new profile image for the user.
    func uploadProfileImage(imageData: Data) -> AnyPublisher<APIResult<String>, APIError> {
        apiManager.uploadProfileImage(imageData: imageData)
    }
    
    /// Resolves userIds from phone numbers.
    func getMatrixUsers(phoneNumbers: [String]) -> AnyPublisher<APIResult<UserMappingResponse>, APIError> {
        apiManager.getMatrixUsers(phoneNumbers: phoneNumbers)
    }

    /// Fetches a user's profile from their Matrix user ID.
    func getUserProfiles(userIds: [String]) -> AnyPublisher<[ProfileResponse], APIError> {
        let trimmedUserIds = userIds.map { $0.trimmedMatrixUserId }
        return apiManager.getUserProfiles(userIds: trimmedUserIds)
            .tryMap { apiResult in
                switch apiResult {
                case .success(let batch):
                    // Map only found results and *patch* userID
                    let patched: [ProfileResponse] = batch.results.compactMap { res in
                        guard res.found, let p = res.data else { return nil }

                        let userIDToUse = res.userID.formattedMatrixUserId
                        
                        return ProfileResponse(
                            _id: p._id,
                            userID: userIDToUse,
                            name: p.name,
                            gender: p.gender,
                            about: p.about,
                            dob: p.dob,
                            profession: p.profession,
                            email: p.email,
                            phone: p.phone,
                            profilePic: p.profilePic,
                            mxcProfile: p.mxcProfile
                        )
                    }

                    return patched

                case .unsuccess(let error):
                    throw error
                }
            }
            .mapError { $0 as? APIError ?? .unknown }
            .eraseToAnyPublisher()
    }
    
    func deleteRoom(roomId: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        apiManager.deleteRoom(roomId: roomId)
    }

    func uploadProfile(file: Data, fileName: String, mimeType: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        apiManager.uplaodProfile(file: file, fileName: fileName, mimeType: mimeType)
    }

}
