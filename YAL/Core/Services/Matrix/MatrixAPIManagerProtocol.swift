//
//  MatrixAPIManagerProtocol.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import Foundation
import Combine

/// Protocol for Matrix API operations
protocol MatrixAPIManagerProtocol {
    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    var syncResponsePublisher: AnyPublisher<APIResult<SyncResponse>, Never> { get }
    var chatMessagesPublisher: AnyPublisher<APIResult<GetMessagesResponse>, APIError> { get }
    
    // Core setup
    func injectHTTPClient(httpClient: HttpClientProtocol)
    func injectAccessToken(_ token: String)
    
    // Authentication
    //func login(username: String, password: String) -> AnyPublisher<APIResult<MatrixLoginResponse>, APIError>
    func restoreSession(accessToken: String)
    //func logout() -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    // Syncing Rooms
    //func syncRooms() -> AnyPublisher<APIResult<SyncResponse>, APIError>
    func startSyncPolling(nextBatch: String?)
    func stopSyncPolling()
    
    // Sending Messages
    func sendMessage(roomId: String, message: MessageRequest) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> 
    
    // Room Operations (Create, Join, Leave)
    func createRoom(createRoomRequest: CreateRoomRequest) -> AnyPublisher<APIResult<CreateRoomResponse>, APIError>
    func joinRoom(roomId: String) -> AnyPublisher<APIResult<JoinRoomResponse>, APIError>
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func getJoinedRooms() -> AnyPublisher<APIResult<JoinedRooms>, APIError>
    
    // Profile Operations
    func getProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError>
    func updateProfile(updateProfileRequest: UpdateProfileRequest) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    // Room Actions (Invite, Kick, Ban)
    func inviteToRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func kickFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func banFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    // File Upload (Presigned URL)
    func getPresignedUrl(fileType: String) -> AnyPublisher<APIResult<PresignedUrlResponse>, APIError>
    
    // Get Messages from Room
    func startSyncMesages(forRoom roomId: String, lastMessageEventId: String?)
    func stopMessageFetching()
//    func backfillMessages(roomId: String, pages: Int, pageSize: Int, startFrom: String?, dir: String) -> AnyPublisher<[GetMessagesResponse], APIError>
    func fetchMessages(forRoom roomId: String, from: String?, limit: Int?, dir: String) -> AnyPublisher<APIResult<GetMessagesResponse>, APIError>
    
    // Room State
    func getRoomState(roomId: String) -> AnyPublisher<APIResult<[Event]>, APIError>
    
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func downloadMediaFile(mxcUrl: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func sendReadMarker(
        roomId: String,
        fullyReadEventId: String?,
        readEventId: String?,
        readPrivateEventId: String?
    ) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    func sendTyping(roomId: String, userId: String, typing: Bool, timeout: Int) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String?
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    
    func sendReaction(roomId: String, eventId: String, emoji: Emoji) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func redactReaction(roomId: String, reactionEventId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func kickFromRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func leaveRoom(roomId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func inviteToRoom(roomId: String, userId:String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func updateRoomName(roomId: String, name: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func updateRoomImage(roomId: String, url: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    
    func registerPusher(request: MatrixPusherSetRequest) -> AnyPublisher<Void, Error>
    func deletePusher(request: MatrixPusherDeleteRequest) -> AnyPublisher<Void, Error>
}
