//
//  ApiManageable.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//


import Combine
import Foundation

protocol ApiManageable {
    func otpLogin(with mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError>
    func resentOTP(with mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError>
    func verify(phoneNumber: String, otp: String, deviceID: String) -> AnyPublisher<APIResult<OTPResponse>, APIError>
    func getProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError>
    func updateProfile(updateProfileRequest: UpdateProfileRequest) -> AnyPublisher<APIResult<EmptyResponse>, APIError>
    func deleteProfile() -> AnyPublisher<APIResult<EmptyResponse>, APIError>
    func getPresignedURL(fileType: String) -> AnyPublisher<APIResult<PresignedUrlResponse>, APIError>
    func uploadProfileImage(imageData: Data) -> AnyPublisher<APIResult<String>, APIError>
    //func refreshToken() -> AnyPublisher<APIResult<OTPResponse>, APIError>
    func saveMessage(header: String, message: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError>
    func getSpamMessages() -> AnyPublisher<APIResult<SpamMessagesResponse>, APIError>
    func getMatrixUsers(phoneNumbers: [String]) -> AnyPublisher<APIResult<UserMappingResponse>, APIError>
    func getUserProfiles(userIds: [String]) -> AnyPublisher<APIResult<BatchUserProfileResponse>, APIError>
    func deleteRoom(roomId: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError>
    func uplaodProfile(file: Data, fileName: String, mimeType: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError>
}

struct EmptyResponse: Decodable {}

enum Endpoint: String {
    
    case signup = "auth/signup"
    case login = "auth/login-synapse"
    case test = "auth/all-users"
    case verify = "auth/verify-synapselogin"
    case resendOtp = "auth/resend-otp"
    case refreshToken = "auth/refresh-token"
    case message = "spam-message"
    case presignedUrl = "v1/user/profile-presigned-Url"
    case profile = "v1/user/profile"
    case profileByPhone = "user/mobile"
    case userMapping = "auth/get-matrix-id"
    case profileByUserId = "/v1/user/get-profile-by-userid"
    case deleteRoom = "v1/group/delete-group"
    case uplaodProfile = "v1/user/upload-profile-image"
    
    var path: String { rawValue }
    
//    var  base: String {
////        return "https://mobile-backend-native.onrender.com/"
//        //return "https://ai.yal.chat/api/"
//        //return "https://uat.yal.chat/api/"
//        return "https://test.yal.chat/api/"
//    }
//    
//    var urlString: String {
//        return base + self.rawValue
//    }
    
//    static let profileImageBasePath = "https://pictur/e.yalai.s3.eu-north-1.amazonaws.com/"
    static let profileImageBasePath = "https://s3.eu-north-1.amazonaws.com/picture.yalai/"

    static let aboutUs = "https://www.yal.chat/about-us"
    
}
