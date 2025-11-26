//
//  ChatRepositoryProtocol.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import Foundation
import Combine

protocol ChatRepositoryProtocol {
    var hydrationProgressPublisher: AnyPublisher<(hydrated: Int, total: Int), Never> { get }
    var messageBackfillProgressPublisher: AnyPublisher<(done: Int, total: Int), Never> { get }
    var redactionPublisher: AnyPublisher<String, Never> { get }
    var roomModelsPublisher: AnyPublisher<[RoomModel], Never> { get }
    var inviteResponsePublisher: AnyPublisher<[String], APIError> { get }
    var chatMessagesPublisher: AnyPublisher<[ChatMessageModel], Never> { get }
    var ephemeralPublisher: AnyPublisher<ReceiptUpdate, Never> { get }
    var typingPublisher: AnyPublisher<TypingUpdate, Never> { get }
    var roomsPublisher: Published<[RoomModel]>.Publisher { get }
    var messageCountsPublisher: AnyPublisher<[String: Int], Never> { get }
    var profileSync: ProfileSyncCoordinator { get }
    func getExistingRoomSummaryModel(roomId: String) -> RoomSummaryModel?
    func upsertRoom(from summary: RoomSummaryModel) -> RoomModel
    func setExpectedRoomsIds(_ ids: [String])
    func enableMessageObservation(for roomId: String)
    func disableMessageObservation()
    func roomsSnapshot() -> [RoomModel]
    func warmCacheIfNeeded(shouldWarmCache: Bool) -> AnyPublisher<Void, Never>

    // Authentication
    //func login(username: String, password: String) -> AnyPublisher<APIResult<MatrixLoginResponse>, APIError>
    func restoreSession(accessToken: String)
    //    func logout() -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    // Syncing Rooms
    func startSync()
    func getJoinedRooms() -> AnyPublisher<APIResult<JoinedRooms>, APIError>
    
    // Sending Messages
    func sendMessage(message: ChatMessageModel) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func sendMessage(message: ChatMessageModel, roomId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func createRoom(currentUser: String, invitees: [String], roomName: String?, roomDisplayImageUrl: String?) -> AnyPublisher<APIResult<CreateRoomResponse>, APIError>
    func getMessages(fromRoom roomId: String, limit: Int)
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func downloadMediaForMessage(mxcUrl: String, fileName: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError>
    func getStateEvents(forRoom roomId: String) -> AnyPublisher<[Event], APIError>
    func sendReadMarker(roomId: String, fullyReadEventId: String?, readEventId: String?, readPrivateEventId: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    //func getRoomModel(forRoomId roomId: String) -> AnyPublisher<RoomModel?, APIError>
    func loadCachedRooms() -> AnyPublisher<[RoomSummaryModel], Never>
    func hydrateRoomSummaries(_ items: [RoomSummaryModel])
    func hydrateRooms(snaps: [RoomModel])
    func getCurrentUserContact() -> ContactLite?
    func getRoomSummaryModel(roomId: String, events: [Event]) -> (RoomSummaryModel, Bool)?
    func updateRooms(with newRooms: [RoomSummaryModel])
    func joinRoom(roomId: String) -> AnyPublisher<APIResult<JoinRoomResponse>, APIError>
    func updateRoom(room: RoomSummaryModel, isExisting: Bool)
    func updateMessageStatus(eventId: String, status: MessageStatus)
    func sendTyping(roomId: String, userId: String, typing: Bool) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func getCommonGroups(with userId: String) -> AnyPublisher<[RoomModel], APIError>
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String?
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func sendReaction(
        roomId: String,
        eventId: String,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func redactReaction(roomId: String, reactionEventId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func kickFromRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func leaveRoom(roomId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func performRoomCleanup(roomId: String) -> AnyPublisher<Void, APIError>
    func inviteToRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func toggleFavoriteRoom(roomID: String)
    func getFavoriteRooms() -> [String]
    func toggleDeletedRoom(roomID: String)
    func getDeletedRooms() -> [String]
    func toggleMutedRoom(roomID: String)
    func getMutedRooms() -> [String]
    func toggleLockedRoom(roomID: String)
    func getLockedRooms() -> [String]
    func toggleMarkedAsUnreadRoom(roomID: String)
    func getUnreadRooms() -> [String]
    func toggleBlockedRoom(roomID: String)
    func getBlockedRooms() -> [String]
    func updateRoomName(roomId: String, name: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func updateRoomImage(roomId: String, url: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError>
    func banFromRoom(roomId: String, userId: String, reason: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError>
    
    func upsertRoomSummary(roomId: String, stateEvents: [Event], timelineEvents: [Event]?, unreadCount: Int)
    
    func fetchFullRoomSummaries(
        ids: [String],
        includeContacts: Bool
    ) -> [RoomSummaryModel]
    func fetchOlderMessages(roomId: String, pageSize: Int) -> AnyPublisher<Bool, APIError>
}

