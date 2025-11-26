//
//  ApiManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//


import Foundation
import Combine

final class ApiManager: ApiManageable {

    private let client: HttpClientProtocol
    private var baseURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    init(httpClient: HttpClientProtocol, env: EnvironmentProviding) {
        self.client = httpClient
        self.baseURL = env.baseURL
        
        // auto-update when environment changes
        env.configPublisher
            .map(\.baseURL)
            .removeDuplicates()
            .sink { [weak self] in self?.baseURL = $0 }
            .store(in: &cancellables)
    }
    
    func uplaodProfile(file: Data, fileName: String, mimeType: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        performPostMultipart(Endpoint.uplaodProfile.path, request: FileUploadRequest(file: file, filename: fileName, mimeType: mimeType), expecting: EmptyResponse.self)
    }
    
    func otpLogin(with mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError> {
        performPost(Endpoint.login.path, SendOtpRequest(mobile: mobile), expecting: LoginResponse.self)
    }
    
    func resentOTP(with mobile: String) -> AnyPublisher<APIResult<LoginResponse>, APIError> {
        performPost(Endpoint.login.path, SendOtpRequest(mobile: mobile), expecting: LoginResponse.self)
    }
    
    func verify(phoneNumber: String, otp: String, deviceID: String) -> AnyPublisher<APIResult<OTPResponse>, APIError> {
        performPost(Endpoint.verify.path, OtpVerifyRequest(mobile: phoneNumber, otp: otp, deviceId: deviceID), expecting: OTPResponse.self)
    }
    
    func getProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError> {
        performGet(Endpoint.profile.path, expecting: ProfileResponse.self)
    }
    
    func updateProfile(updateProfileRequest: UpdateProfileRequest) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        performPut(Endpoint.profile.path, updateProfileRequest, expecting: EmptyResponse.self)
    }
    
    func deleteProfile() -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        performDelete("/auth/delete", MatrixEmptyRequest(), expecting: EmptyResponse.self)
    }
    
    func getPresignedURL(fileType: String) -> AnyPublisher<APIResult<PresignedUrlResponse>, APIError> {
        performPost(Endpoint.presignedUrl.path, PreSignedUrlRequest(fileType: fileType), expecting: PresignedUrlResponse.self)
    }
    
    func uploadProfileImage(imageData: Data) -> AnyPublisher<APIResult<String>, APIError> {
        getPresignedURL(fileType: "png")
            .flatMap { result -> AnyPublisher<APIResult<String>, APIError> in
                guard case let .success(response) = result else {
                    return Fail(error: .fileUploadFailed).eraseToAnyPublisher()
                }
                
                return Future<APIResult<String>, APIError> { promise in
                    Task {
                        let uploadResult = await self.client.upload(to: response.presignedUrl, data: imageData)
                        switch uploadResult {
                        case .success:
                            promise(.success(uploadResult))
                        case .unsuccess(let error):
                            promise(.failure(error))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
//    func refreshToken() -> AnyPublisher<APIResult<OTPResponse>, APIError> {
//        performPost("/auth/refresh", TokenRefreshRequest(refreshToken: DBManager.shared.refreshToken), expecting: OTPResponse.self)
//    }
    
    func saveMessage(header: String, message: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        performPost("/sms", SaveMessageRequest(responseHeader: header, message: message), expecting: EmptyResponse.self)
    }
    
    func getSpamMessages() -> AnyPublisher<APIResult<SpamMessagesResponse>, APIError> {
        performGet("/sms", expecting: SpamMessagesResponse.self)
    }
    
    func getMatrixUsers(phoneNumbers: [String]) -> AnyPublisher<APIResult<UserMappingResponse>, APIError> {
        performPost(
            Endpoint.userMapping.path,
            UserMappingRequest(phoneNumbers: phoneNumbers),
            expecting: UserMappingResponse.self
        )
    }
    
    func getUserProfiles(userIds: [String]) -> AnyPublisher<APIResult<BatchUserProfileResponse>, APIError> {
        performPost(
            Endpoint.profileByUserId.path,
            UserProfileRequest(userIDs: userIds.map { $0.trimmedMatrixUserId }),
            expecting: BatchUserProfileResponse.self
        )
    }
    
    func deleteRoom(roomId: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        performDelete(
            Endpoint.deleteRoom.path,
            DeleteRoomRequest(roomId: roomId),
            expecting: EmptyResponse.self
        )
            
    }
}

private extension ApiManager {
    func absolute(_ pathOrURL: String) -> String {
        if pathOrURL.hasPrefix("http://") || pathOrURL.hasPrefix("https://") {
            return pathOrURL
        }
        let trimmed = pathOrURL.hasPrefix("/") ? String(pathOrURL.dropFirst()) : pathOrURL
        return baseURL.appendingPathComponent(trimmed).absoluteString
    }
    
    func performGet<T: Decodable>(_ path: String, expecting: T.Type) -> AnyPublisher<APIResult<T>, APIError> {
        Future { [self] promise in
            Task {
                let result = await client.get(absolute(path), response: expecting)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }

    func performPost<T: Encodable, R: Decodable>(_ path: String, _ body: T, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                let result = await client.post(absolute(path), body: body, expecting: expecting)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }

    func performPut<T: Encodable, R: Decodable>(_ path: String, _ body: T, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                let result = await client.put(absolute(path), body: body, expecting: expecting)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }

    func performDelete<T: Encodable, R: Decodable>(_ path: String, _ body: T, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                let result = await client.delete(absolute(path), body: body, expecting: expecting)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func performPostMultipart<R: Decodable>(_ path: String, request: FileUploadRequest, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                let result: APIResult<R> = await client.postMultipart(absolute(path), fileUploadRequest: request, expecting: expecting)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
}
