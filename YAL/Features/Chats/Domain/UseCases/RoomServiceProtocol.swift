//
//  RoomServiceProtocol.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/06/25.
//

import Combine
import Foundation

enum RoomProgressEvent {
    case started(id: String, index: Int, allIds: [String])
    case succeeded(id: String, index: Int, allIds: [String])
    case failed(id: String, index: Int, allIds: [String], error: APIError)
}

protocol RoomServiceProtocol {
    var hydrationProgressPublisher: AnyPublisher<(hydrated: Int, total: Int), Never> { get }
    var messageBackfillProgressPublisher: AnyPublisher<(done: Int, total: Int), Never> { get }
    var redactionPublisher: AnyPublisher<String, Never> { get }
    var chatMessagesPublisher: AnyPublisher<[ChatMessageModel], Never> { get }
    var messagesClearedPublisher: AnyPublisher<String, Never> { get }
    var ephemeralPublisher: AnyPublisher<ReceiptUpdate, Never> { get }
    var typingPublisher: AnyPublisher<TypingUpdate, Never> { get }
    var roomsPublisher: AnyPublisher<[RoomModel], Never> { get }
    var inviteResponsePublisher: AnyPublisher<[String], APIError> { get }
    var messageCountsPublisher: AnyPublisher<[String: Int], Never> { get }
    
    func loadCacheAndHydrateRoomsNow(includeContacts: Bool)
    func roomsSnapshot() -> [RoomModel]
    func warmRoomsCacheIfNeeded(shouldWarmCache: Bool) -> AnyPublisher<Void, Never>
    func setExpectedRoomsIds(_ ids: [String])
    func getMessages(forRoom roomId: String)
    func stopMessageSync()
    func sendMessage(message: ChatMessageModel) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func sendMessage(message: ChatMessageModel, roomId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func downloadMediaForMessage(mxcUrl: String, fileName: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func sendReadMarker(roomId: String, fullyReadEventId: String?, readEventId: String?, readPrivateEventId: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func restoreSession(accessToken: String)
    func fetchAndPopulateRooms(onlyCache: Bool) -> AnyPublisher<RoomProgressEvent, APIError>
    func startSync()
    func createAndFetchRoomModel(
        currentUser: String,
        invitees: [String],
        roomName: String?,
        roomDisplayImageUrl: String?
    ) -> AnyPublisher<RoomModel?, APIError>
    func joinAndFetchRoomModel(roomId: String) -> AnyPublisher<RoomModel?, APIError>
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func updateMessageStatus(eventId: String, status: MessageStatus)
    func sendTyping(roomId: String, userId: String, typing: Bool) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func getCommonGroups(with userId: String) -> AnyPublisher<[RoomModel], APIError>
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String?
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func sendReaction(
        to message: ChatMessageModel,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func updateReaction(
        message: ChatMessageModel,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func kickUserFromRoom(room: RoomModel, user: ContactModel, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func leaveRoom(room: RoomModel, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func fetchAndUpdateAllRoomsState(rooms: [RoomModel])
    func fetchAndUpdateRoomState(room: RoomModel)
    func deleteRoom(room: RoomModel, reason: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError>
    func inviteUserToRoom(room: RoomModel, user: ContactLite, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func inviteUsersToRoom(
        room: RoomModel,
        users: [ContactLite],
        reason: String
    ) -> AnyPublisher<[(ContactLite, APIResult<MatrixEmptyResponse>)], APIError>
    func toggleFavoriteRoom(roomID: String)
    func getFavoriteRooms() -> [String]
    func toggleMarkedAsUnreadRoom(roomID: String)
    func getUnreadRooms() -> [String]
    func toggleBlockedRoom(roomID: String)
    func getBlockedRooms() -> [String]
    func toggleLockedRoom(roomID: String)
    func getLockedRooms() -> [String]
    func toggleMutedRoom(roomID: String)
    func getMutedRooms() -> [String]
    func toggleDeletedRoom(roomID: String)
    func getDeletedRooms() -> [String]
    func updateRoomName(room: RoomModel, newName: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func updateRoomImage(room: RoomModel, newUrl: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func banFromRoom(roomId: String, userId: String, reason: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func enableMessageObservation(for roomId: String)
    func disableMessageObservation()
    func fetchOlderMessages(roomId: String, pageSize: Int) -> AnyPublisher<Bool, APIError>
}
