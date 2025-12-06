//
//  LoginRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import Foundation
import UIKit

// MARK: - Matrix Login Request

struct MatrixLoginRequest: Codable {
    let type: String
    let user: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case type
        case user = "user_id"
        case password
    }
}

// MARK: - Matrix Login Response

struct MatrixLoginResponse: Codable {
    let accessToken: String
    let deviceId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case deviceId = "device_id"
        case userId = "user_id"
    }
}

// MARK: - Room Sync Response

struct RoomSyncResponse: Codable {
    let rooms: [String: Room]

    enum CodingKeys: String, CodingKey {
        case rooms
    }
}

// MARK: - Send Message Request

struct SendMessageRequest: Codable {
    let msgType: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case msgType = "msgtype"
        case body
    }
}

// MARK: - Send Message Response

struct SendMessageResponse: Codable {
    let eventId: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
    }
}

// MARK: - Profile Management

struct MatrixProfileResponse: Codable {
    let userId: String
    let displayName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct UpdateMatrixProfileRequest: Codable {
    let displayName: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct MatrixEmptyRequest: Encodable {}

struct MatrixEmptyResponse: Codable {}

struct RedactEventRequest: Codable {
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case reason
    }
}

struct KickUserRequest: Codable {
    let userId: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case reason
    }
}

struct InviteUserRequest: Codable {
    let userId: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case reason
    }
}

struct RoomNameRequest: Request {
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name
    }
}

struct RoomImageRequest: Request {
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case url
    }
}

struct LeaveRoomRequest: Codable {
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case reason
    }
}

struct RoomLeaveRequest: Codable {
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case reason
    }
}

struct ReactionRequest: Request {
    let relatesToRequest: RelatesToRequest
    
    enum CodingKeys: String, CodingKey {
        case relatesToRequest = "m.relates_to"
    }
    
    init(emoji: Emoji, eventId: String) {
        relatesToRequest = RelatesToRequest(key: emoji.symbol, relType: "m.annotation", eventId: eventId)
    }
}

// MARK: - Create Room

//struct CreateRoomRequest: Codable {
//    let visibility: String
//    let roomVersion: String
//    let name: String
//    let topic: String?
//
//    enum CodingKeys: String, CodingKey {
//        case visibility = "room_visibility"
//        case roomVersion = "room_version"
//        case name = "room_name"
//        case topic = "room_topic"
//    }
//}

struct JoinedRooms: Codable {
    let joinedRooms: [String]?
    
    enum CodingKeys: String, CodingKey {
        case joinedRooms = "joined_rooms"
    }
}

struct CreateRoomResponse: Codable {
    let roomId: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
    }
}

struct JoinRoomResponse: Codable {
    let roomId: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
    }
}

struct ReadMarkerRequest: Request {
    let mFullyRead: String
    let mRead: String?
    let mReadPrivate: String?
    
    enum CodingKeys: String, CodingKey {
        case mRead = "m.read"
        case mFullyRead = "m.fully_read"
        case mReadPrivate = "m.read.private"
    }
}

struct TypingRequest: Request {
    let typing: Bool
    let timeout: Int
}


// MARK: - Room Actions (Invite, Kick, Ban)

struct InviteRoomRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct KickRoomRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct BanRoomRequest: Codable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - File Upload

struct MatrixPreSignedUrlRequest: Codable {
    let fileType: String

    enum CodingKeys: String, CodingKey {
        case fileType = "file_type"
    }
}

struct MatrixPresignedUrlResponse: Codable {
    let presignedUrl: String

    enum CodingKeys: String, CodingKey {
        case presignedUrl = "presigned_url"
    }
}

// MARK: - GetMessagesResponse (Top level)
struct GetMessagesResponse: Codable {
    let start: String?
    let end: String?
    let chunk: [Message] // Array of messages

    // Coding Keys are automatically handled due to snake_case and camelCase mapping.
}

struct MessagesFilter: Codable {
    var types: [String]?          // e.g. ["m.room.message", "m.room.encrypted"]
    var notTypes: [String]?
    var senders: [String]?
    var notSenders: [String]?
    var containsURL: Bool?

    enum CodingKeys: String, CodingKey {
        case types
        case notTypes    = "not_types"
        case senders
        case notSenders  = "not_senders"
        case containsURL = "contains_url"
    }
}

// MARK: - Message (Individual chat message)
struct Message: Codable {
    let eventId: String?  // Event ID
    let sender: String?   // Sender of the message
    let content: MessageContent?  // The content of the message
    let type: String?     // The type of event (e.g., "m.room.message")
    let roomId: String?   // Room ID where the message was sent
    let originServerTs: Int64?  // Timestamp of when the message was sent on the server
    let unsigned: UnsignedData?  // Additional unsigned data, like "age"
    let userId: String?
    let age: Int64?
    let url: String?
    let redacts: String?
    
    // Coding keys for mapping response keys to model properties
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case sender
        case content
        case type
        case roomId = "room_id"
        case originServerTs = "origin_server_ts"
        case unsigned
        case userId = "user_id"
        case age
        case url
        case redacts
    }
}

// MARK: - Message Content (Body and Type)
struct MessageContent: Codable {
    let body: String?          // The body of the message
    let msgType: String?      // Message type (e.g., "m.text", "m.image", etc.)
    let formattedBody: String? // Formatted message body (e.g., HTML)
    let url: String?           // URL (used for links, media, etc.)
    let info: MediaInfo?      // Media information (e.g., for images/videos)
    let relatesTo: RelatesToContent?  // For replies or relations
    let reason: String?
    let redacts: String?
    
    // Coding keys for correct mapping
    enum CodingKeys: String, CodingKey {
        case body
        case msgType = "msgtype"
        case formattedBody = "formatted_body"
        case url
        case info
        case relatesTo = "m.relates_to"
        case reason
        case redacts
    }
}

// For reply relation content
struct RelatesToContent: Codable {
    let inReplyTo: InReplyToContent?
    let eventId: String?
    let relType: String?
    let key: String?

    enum CodingKeys: String, CodingKey {
        case inReplyTo = "m.in_reply_to"
        case eventId = "event_id"
        case relType = "rel_type"
        case key
    }
}

struct InReplyToContent: Codable {
    let eventId: String
    let relType: String?
    let key: String?
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case relType = "rel_type"
        case key
    }
}

// MARK: - Media Info (For videos, images, etc.)
struct MediaInfo: Codable, Equatable {
    let thumbnailUrl: String?
    let thumbnailInfo: MediaThumbnail?
    let w: Int?
    let h: Int?
    let duration: Int?
    let size: Int?
    let mimetype: String?
    var localURL: URL? = nil
    var progress: Double? = nil

    enum CodingKeys: String, CodingKey {
        case thumbnailUrl = "thumbnail_url"
        case thumbnailInfo = "thumbnail_info"
        case w, h, duration, size, mimetype
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "mimetype": mimetype ?? "image/png",
            "size": size ?? 0
        ]
        if let width = w, let height = h {
            dict["w"] = width
            dict["h"] = height
        }
        if let duration = duration {
            dict["duration"] = duration
        }
        if let thumb = thumbnailUrl, let thumbInfo = thumbnailInfo {
            dict["thumbnail_url"] = thumb
            dict["thumbnail_info"] = [
                "w": thumbInfo.w ?? 0,
                "h": thumbInfo.h ?? 0,
                "size": thumbInfo.size ?? 0,
                "mimetype": thumbInfo.mimetype ?? "image/png"
            ]
        }
        return dict
    }
}

// MARK: - Media Thumbnail (For image/media thumbnail details)
struct MediaThumbnail: Codable, Equatable {
    let mimetype: String?  // MIME type of the thumbnail
    let size: Int?         // Size of the thumbnail (in bytes)
    let w: Int?            // Width of the thumbnail
    let h: Int?            // Height of the thumbnail

    // Coding keys for mapping
    enum CodingKeys: String, CodingKey {
        case mimetype
        case size
        case w
        case h
    }
}

// MARK: - Unsigned Data (Additional unsigned data like age)
struct UnsignedData: Codable {
    let age: Int?                 // Time since sent
    let membership: String?
    let redactedBy: String?       // The event_id of the redaction event
    let redactedBecause: RedactedBecauseData?

    enum CodingKeys: String, CodingKey {
        case age
        case membership
        case redactedBy = "redacted_by"
        case redactedBecause = "redacted_because"
    }
}

struct RedactedBecauseData: Codable {
    let type: String?                // Should be "m.room.redaction"
    let roomId: String?
    let sender: String?
    let content: RedactionContent?
    let redacts: String?             // The event_id being redacted
    let eventId: String?
    let originServerTs: Int?
    let unsigned: RedactionUnsigned?
    let userId: String?
    let age: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case roomId = "room_id"
        case sender
        case content
        case redacts
        case eventId = "event_id"
        case originServerTs = "origin_server_ts"
        case unsigned
        case userId = "user_id"
        case age
    }
}

struct RedactionContent: Codable {
    let reason: String?
    let redacts: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case redacts
    }
}

struct RedactionUnsigned: Codable {
    let age: Int?

    enum CodingKeys: String, CodingKey {
        case age
    }
}

// MARK: - SyncResponse

struct SyncResponse: Codable {
    let nextBatch: String?
    let accountData: AccountData?
    let presence: Presence?
    let deviceOneTimeKeysCount: DeviceOneTimeKeysCount?
    let rooms: Rooms?
    let unreadNotifications: UnreadNotifications?
    
    enum CodingKeys: String, CodingKey {
        case nextBatch = "next_batch"
        case accountData = "account_data"
        case presence
        case deviceOneTimeKeysCount = "device_one_time_keys_count"
        case rooms
        case unreadNotifications = "unread_notifications"
    }
}

// MARK: - AccountData

struct AccountData: Codable {
    let events: [Event]?
}

// MARK: - EventContent

struct EventContent: Codable {
    let roomVersion: String?
    let creator: String?
    let name: String?
    let historyVisibility: String?
    let membership: String?
    let displayname: String?
    let powerLevels: PowerLevels?
    let joinRule: String?
    let url: String?
    let avatarUrl: String?
    let canonicalAlias: String?
    let msgType: String?
    let body: String?
    let creatorId: String?
    let isDirect: Bool = false
    let users: [String: Int]?
    
    enum CodingKeys: String, CodingKey {
        case roomVersion = "room_version"
        case creator
        case name
        case historyVisibility = "history_visibility"
        case membership
        case displayname
        case powerLevels = "power_levels"
        case joinRule = "join_rule"
        case url
        case avatarUrl = "avatar_url"
        case canonicalAlias = "canonical_alias"
        case msgType = "msgtype"
        case body
        case creatorId = "creator_id"
        case isDirect = "is_direct"
        case users
    }
}

// MARK: - PowerLevels

struct PowerLevels: Codable {
    let usersDefault: Int?
    let events: [String: Int]?
    let eventsDefault: Int?
    let ban: Int?
    let kick: Int?
    let redact: Int?
    let invite: Int?
    let historical: Int?
    
    enum CodingKeys: String, CodingKey {
        case usersDefault = "users_default"
        case events
        case eventsDefault = "events_default"
        case ban
        case kick
        case redact
        case invite
        case historical
    }
}

// MARK: - UnsignedEvent

struct UnsignedEvent: Codable {
    let membership: String?
    let age: Int?
    
    enum CodingKeys: String, CodingKey {
        case membership
        case age
    }
}

// MARK: - Presence

struct Presence: Codable {
    let events: [PresenceEvent]?
}

// MARK: - PresenceEvent

struct PresenceEvent: Codable {
    let type: String?
    let sender: String?
    let content: PresenceContent?
}

// MARK: - PresenceContent

struct PresenceContent: Codable {
    let presence: String?
    let lastActiveAgo: Int?
    let currentlyActive: Bool?
    let statusMessage: String?
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case presence
        case lastActiveAgo = "last_active_ago"
        case currentlyActive = "currently_active"
        case statusMessage = "status_msg"
        case avatarURL = "avatar_url"
    }
}

// MARK: - DeviceOneTimeKeysCount

struct DeviceOneTimeKeysCount: Codable {
    let signedCurve25519: Int?
}

// MARK: - Rooms

struct Rooms: Codable {
    let join: [String: Room]?
    let invite: [String: RoomInvite]?
    let knock: [String: RoomInvite]?
    let leave: [String: Room]?
    
    enum CodingKeys: String, CodingKey {
        case join
        case invite
        case knock
        case leave
    }
}

struct RoomInvite: Codable {
    var inviteState: InviteState?
    
    enum CodingKeys: String, CodingKey {
        case inviteState = "invite_state"
    }
}

struct InviteState: Codable {
    var events: [StrippedStateEvent]?
}

struct StrippedStateEvent: Codable {
    var stateKey: String?
    var content: EventContent?
    var sender: String?
    var type: String?
    
    enum CodingKeys: String, CodingKey {
        case stateKey = "state_key"
        case content
        case sender
        case type
    }
}

// MARK: - Room

struct Room: Codable {
    let timeline: Timeline?
    let prevBatch: String?
    let limited: Bool?
    let state: StateEvents?
    let accountData: AccountData?
    let ephemeral: EphemeralData?
    let unreadNotifications: UnreadNotifications?
    let summary: RoomSummary?
    
    enum CodingKeys: String, CodingKey {
        case timeline
        case prevBatch = "prev_batch"
        case limited
        case state
        case accountData = "account_data"
        case ephemeral
        case unreadNotifications = "unread_notifications"
        case summary
    }
}

// MARK: - Timeline

struct StateEvents: Codable {
    let events: [Event]?
}

struct Timeline: Codable {
    var events: [TimelineEvent]?
}

extension TimelineEvent {
    func asEvent(roomId: String? = nil) -> Event {
        Event(
            type: type,
            content: content,
            sender: sender,
            eventId: eventId,
            stateKey: stateKey,
            originServerTs: originServerTs,
            unsigned: unsigned,
            roomId: roomId
        )
    }
}

extension Sequence where Element == TimelineEvent {
    func asEvents(roomId: String? = nil) -> [Event] {
        map { $0.asEvent(roomId: roomId) }
    }
}

// MARK: - Event

struct Event: Codable {
    let type: String?
    let content: EventContent?
    let sender: String?
    let eventId: String?
    let stateKey: String?
    let originServerTs: Int64?
    let unsigned: UnsignedEvent?
    let roomId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case sender
        case eventId = "event_id"
        case stateKey = "state_key"
        case originServerTs = "origin_server_ts"
        case unsigned
        case roomId = "room_id"
    }
}

// MARK: - TimelineEvent

struct TimelineEvent: Codable {
    let type: String?
    let sender: String?
    let content: EventContent?
    let eventId: String?
    let stateKey: String?
    let originServerTs: Int64?
    let unsigned: UnsignedEvent?
    let prevBatch: String?
    let limited: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case sender
        case content
        case eventId = "event_id"
        case stateKey = "state_key"
        case originServerTs = "origin_server_ts"
        case unsigned
        case prevBatch = "prev_batch"
        case limited
    }
}

// MARK: - UnreadNotifications

struct UnreadNotifications: Codable {
    let notificationCount: Int?
    let highlightCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case notificationCount = "notification_count"
        case highlightCount = "highlight_count"
    }
}

// MARK: - EphemeralData

struct EphemeralData: Codable {
    let events: [EphemeralEvent]
}

struct EphemeralEvent: Codable {
    let type: String
    let content: EphemeralContent
}

enum EphemeralContent: Codable {
    case typing(TypingContent)
    case receipt(ReceiptContent)
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try decode as Typing
        if let typing = try? container.decode(TypingContent.self) {
            self = .typing(typing)
            return
        }

        // Try decode as Receipt
        if let receipt = try? container.decode(ReceiptContent.self) {
            self = .receipt(receipt)
            return
        }

        // Unknown type fallback
        self = .unknown
    }
}

struct TypingContent: Codable {
    let userIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case userIds = "user_ids"
    }
}

struct ReceiptContent: Codable {
    let receipts: [String: ReceiptEvent]  // eventId → ReceiptEvent

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var map: [String: ReceiptEvent] = [:]

        for key in container.allKeys {
            let receiptEvent = try container.decode(ReceiptEvent.self, forKey: key)
            map[key.stringValue] = receiptEvent
        }

        self.receipts = map
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

struct ReceiptEvent: Codable {
    let read: [String: ReceiptInfo]?
    let readPrivate: [String: ReceiptInfo]?
    let fullyRead: [String: ReceiptInfo]?

    enum CodingKeys: String, CodingKey {
        case read = "m.read"
        case readPrivate = "m.read.private"
        case fullyRead = "m.fully_read"
    }
}

struct ReceiptInfo: Codable {
    let ts: Int64
}

enum ReadStatus: String {
    case read = "m.read"
    case readPrivate = "m.read.private"
    case fullyRead = "m.fully_read"
}

// MARK: - RoomSummary

struct RoomSummary: Codable {
    let users: [String]?
    let invitedMemberCount: Int?
    let joinedMemberCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case users = "m.heroes"
        case invitedMemberCount = "m.invited_member_count"
        case joinedMemberCount = "m.joined_member_count"
    }
}

// MARK: - Reusable Room Content

struct RoomContent: Codable {
    let roomVersion: String?
    let creator: String?
    let name: String?
}

enum MessageType: String, Codable {
    case text = "m.text"
    case image = "m.image"
    case file = "m.file"
    case video = "m.video"
    case audio = "m.audio"
    case gif = "m.gif"
    
    init(from raw: String?) {
        self = MessageType(rawValue: raw ?? "") ?? .text
    }
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case read
    
    var imageName: String {
        switch self {
        case .sending:
            return "sent"
        case .sent:
            return "sent"
        case .read:
            return "read"
        }
    }
}

// MARK: - Push Rules Models
struct PushRuleActionsRequest: Encodable {
    let actions: [String]

    enum CodingKeys: String, CodingKey {
        case actions
    }
}

enum MuteDuration: CaseIterable{
    case eightHours
    case oneWeek
    case day
    case always
    
    // Return the duration in milliseconds (or a suitable format for your API)
    var durationInMilliseconds: Int {
        switch self {
        case .eightHours:
            return 8 * 60 * 60 * 1000 // 8 hours in milliseconds
        case .oneWeek:
            return 7 * 24 * 60 * 60 * 1000 // 1 week in milliseconds
        case .day:
            return 24 * 60 * 60 * 1000
        case .always:
            return -1 // Represent "always" as -1 (permanent mute)
        }
    }
    
    // Return a human-readable label for the duration
    var label: String {
        switch self {
        case .eightHours:
            return "8 hours"
        case .oneWeek:
            return "1 week"
        case .day:
            return "24 hours"
        case .always:
            return "Always"
        }
    }
}
