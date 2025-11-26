//
//  DBManageable.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//


import Foundation
import RealmSwift
import Combine

protocol DBManageable {
    static var shared: DBManageable { get }
    var realm: Realm { get }
    func makeRealm() -> Realm
    func withRealm<T>(_ work: (Realm) throws -> T) throws -> T
    func write(_ block: (Realm) throws -> Void, withoutNotifying tokens: [NotificationToken]) throws
    func write(_ block: (Realm) throws -> Void) throws
    func saveContacts(contacts: [ContactLite])
    func saveContact(contact: ContactLite)
    func fetchContacts() -> [ContactLite]?
    func fetchContact(userId: String) -> ContactLite? 
    func update(contacts: [ContactModel])
    func upsertContactPresence(userId: String, currentlyActive: Bool?, lastActiveAgoMs: Int?, avatarURL: String?, statusMessage: String?)
    
    func fetchRooms() -> [RoomSummaryModel]?
    func saveRooms(rooms: [RoomModel])
    func saveRoom(room: RoomModel)
    func saveRoomSummary(_ summary: RoomSummaryModel)
    func loadRoomSummary(roomId: String) -> RoomSummaryModel?
    
    func fetchRoomSync() -> RoomSyncObject?
    func saveRoomSync(nextBatch: String)
    
    func saveMessage(message: ChatMessageModel, inRoom roomId: String, inReplyTo replyToEventId: String?)
    func saveMessages(messages: [ChatMessageModel], inRoom roomId: String)
    func countMessages(inRoom roomId: String) -> Int
    func fetchMessages(inRoom roomId: String) -> [ChatMessageModel]
    func deleteMessages(inRoom roomId: String)
    func deleteMessage(eventId: String)
    func markMessageRedacted(eventId: String)
    func deleteRoomById(roomId: String)
    func deleteAllMessages()
    
    func fetchMessageSync(for roomId: String) -> MessageSyncObject?
    func saveMessageSync(roomId: String, firstEvent: String?, lastEvent: String?)
    func updateReceipts(forRoom roomId: String, content: EphemeralContent, currentUserId: String)
    func updateMessageStatus(eventId: String, status: MessageStatus)
    func getMessageIfExists(eventId: String) -> ChatMessageModel?
    func updateMessage(message: ChatMessageModel, inRoom roomId: String, inReplyTo replyToEventId: String?)
    func addReactionToMessage(messageEventId: String, reactionEventId: String, userId: String, emojiKey: String, timestamp: Int64)
    
    func streamRoomHydrations(sortKey: String, ascending: Bool, limit: Int?, batchSize: Int, batchDelay: TimeInterval) -> AnyPublisher<[RoomHydrationPayload], Never>
    func clearAllSync(purgeFiles: Bool)
    
    func fetchFullRoomSummaries(
        ids: [String]?,
        limit: Int?,
        sortKey: String,
        ascending: Bool,
        includeContacts: Bool,
        resolveContact: ((String) -> ContactLite?)?
    ) -> [RoomSummaryModel]
}
