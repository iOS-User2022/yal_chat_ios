//
//  DBManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation
import RealmSwift
import Combine

struct RoomHydrationPayload {
    let id: String
    let currentUser: String?
    let creator: String?
    let createdAt: Int64?
    let avatarUrl: String?
    let lastMessage: String?
    let lastMessageType: String?
    let lastSender: String?
    let lastSenderName: String?
    let unreadCount: Int
    let joinedMembers: [String]
    let invitedMembers: [String]
    let leftMembers: [String]
    let bannedMembers: [String]
    let admins: [String]
    let stateEvents: [Event]
    let serverTimestamp: Int64?
    let lastServerTimestamp: Int64?
}

final class RoomCardProjection: Projection<RoomObject> {
    @Projected(\RoomObject.id) var id: String
    @Projected(\RoomObject.name) var name: String
    @Projected(\RoomObject.avatarUrl) var avatarUrl: String?
    @Projected(\RoomObject.lastMessage) var lastMessage: String?
    @Projected(\RoomObject.lastMessageType) var lastMessageType: String?
    @Projected(\RoomObject.lastSenderName) var lastSenderName: String?
    @Projected(\RoomObject.unreadCount) var unreadCount: Int
    @Projected(\RoomObject.numberOfParticipants) var numberOfParticipants: Int
    @Projected(\RoomObject.serverTimestamp) var serverTimestamp: Int64?
}

// MARK: — Realm Models

/// Stores one ContactModel
class ContactObject: Object {
    @Persisted(primaryKey: true) var id: String              // ContactModel.id
    @Persisted           var fullName: String?
    @Persisted           var phoneNumber: String
    @Persisted           var emailData: Data?                // JSON-encoded [String]
    @Persisted           var imageData: Data?
    @Persisted           var imageURL: String?
    @Persisted           var userId: String?
    @Persisted           var displayName: String?
    @Persisted           var lastSeen: Int?
    @Persisted           var avatarURL: String?
    @Persisted           var statusMessage: String?
    @Persisted           var dob: String?
    @Persisted           var gender: String?
    @Persisted           var profession: String?
    @Persisted           var isBlocked: Bool = false
    @Persisted           var isSynced: Bool = false
}

/// Stores one RoomModel
class RoomObject: Object {
    @Persisted(primaryKey: true) var id: String              // RoomModel.id
    @Persisted           var name: String
    @Persisted           var creator: String
    @Persisted           var createdAt: Int64?
    @Persisted           var currentUser: Data?
    @Persisted           var joinedMembersData: Data?
    @Persisted           var invitedMembersData: Data?
    @Persisted           var leftMembersData: Data?
    @Persisted           var bannedMembersData: Data?
    @Persisted           var lastMessage: String?
    @Persisted           var lastMessageType: String?
    @Persisted           var lastSender: String?
    @Persisted           var unreadCount: Int
    @Persisted           var avatarUrl: String?
    @Persisted           var serverTimestamp: Int64?
    @Persisted           var lastServerTimestamp: Int64?
    @Persisted           var adminData: Data?              // JSON-encoded [ContactModel]
    @Persisted           var isLeft: Bool
    @Persisted           var state: Data?
    @Persisted           var lastSenderName: String?
    @Persisted           var numberOfParticipants: Int
}

/// Stores one RoomModel
class RoomSummaryObject: Object {
    @Persisted(primaryKey: true) var id: String              // RoomModel.id
    @Persisted           var name: String
    @Persisted           var creator: String
    @Persisted           var createdAt: Int64?
    @Persisted           var currentUser: Data?
    @Persisted           var opponentUserData: Data?
    @Persisted           var joinedMembersData: Data?
    @Persisted           var invitedMembersData: Data?
    @Persisted           var leftMembersData: Data?
    @Persisted           var bannedMembersData: Data?
    @Persisted           var lastMessage: String?
    @Persisted           var lastMessageType: String?
    @Persisted           var lastSender: String?
    @Persisted           var unreadCount: Int
    @Persisted           var avatarUrl: String?
    @Persisted           var serverTimestamp: Int64?
    @Persisted           var lastServerTimestamp: Int64?
    @Persisted           var adminData: Data?              // JSON-encoded [ContactModel]
    @Persisted           var isLeft: Bool
    @Persisted           var state: Data?
    @Persisted           var lastSenderName: String?
    @Persisted           var numberOfParticipants: Int
}


/// Stores the global “nextBatch” token
class RoomSyncObject: Object {
    @Persisted(primaryKey: true) var id: String = "global"
    @Persisted           var nextBatch: String
}

/// Stores per-room “lastEvent” token
class MessageSyncObject: Object {
    @Persisted(primaryKey: true) var roomId: String
    @Persisted           var lastEvent: String
    @Persisted           var firstEvent: String
}

class ReadReceiptObject: Object {
    @Persisted var userId: String
    @Persisted var timestamp: Int64
    @Persisted var status: String // store ReadStatus.rawValue
}

class MessageReactionObject: EmbeddedObject {
    @Persisted var eventId: String      // event_id of the reaction event
    @Persisted var userId: String       // Who sent the reaction
    @Persisted var key: String          // The emoji (e.g., "👍")
    @Persisted var timestamp: Int64     // Reaction event timestamp
}

/// Stores one chat message
class MessageObject: Object {
    @Persisted(primaryKey: true) var eventId: String
    @Persisted           var roomId:   String
    @Persisted           var sender:   String
    @Persisted           var content:  String
    @Persisted           var timestamp:Int64
    @Persisted           var msgType:  String
    @Persisted           var mediaUrl: String?
    @Persisted           var mediaInfo: MediaInfoEntity?
    @Persisted           var thumbnailUrl: String?
    @Persisted           var mediaSize:    Int
    @Persisted           var currentUserId: String?
    @Persisted           var receipts: Data?
    @Persisted           var messageStatus: String?
    @Persisted           var inReplyTo: String?
    @Persisted           var reactions: List<MessageReactionObject>
    @Persisted           var isRedacted: Bool = false

    convenience init(from model: ChatMessageModel) {
        self.init()
        self.eventId = model.eventId
        self.roomId   = model.roomId
        self.sender   = model.sender
        self.content  = model.content
        self.timestamp = model.timestamp
        self.msgType  = model.msgType
        self.mediaUrl = model.mediaUrl
        self.mediaInfo = model.mediaInfo.map { MediaInfoEntity(from: $0) }
        self.thumbnailUrl = model.mediaInfo?.thumbnailUrl
        self.mediaSize = model.mediaSize?.count ?? 0
        self.currentUserId = model.currentUserId
        self.receipts = try? JSONEncoder().encode(model.receipts)
        self.messageStatus = model.messageStatus.rawValue
        self.reactions.removeAll()
        for reaction in model.reactions {
            let obj = MessageReactionObject()
            obj.eventId = reaction.eventId
            obj.userId = reaction.userId
            obj.key = reaction.key
            obj.timestamp = reaction.timestamp
            self.reactions.append(obj)
        }
        self.isRedacted = model.isRedacted
    }
}

class MediaInfoEntity: EmbeddedObject {
    @Persisted var thumbnailUrl: String?
    @Persisted var thumbnailInfo: MediaThumbnailEntity?
    @Persisted var w: Int?
    @Persisted var h: Int?
    @Persisted var duration: Int?
    @Persisted var size: Int?
    @Persisted var mimetype: String?
    @Persisted var localPath: String?
    @Persisted var progress: Double?

    convenience init(from model: MediaInfo) {
        self.init()
        self.thumbnailUrl = model.thumbnailUrl
        self.thumbnailInfo = model.thumbnailInfo.map { MediaThumbnailEntity(from: $0) }
        self.w = model.w
        self.h = model.h
        self.duration = model.duration
        self.size = model.size
        self.mimetype = model.mimetype
        self.localPath = model.localURL?.path
        self.progress = model.progress
    }

    func toModel() -> MediaInfo {
        return MediaInfo(
            thumbnailUrl: thumbnailUrl,
            thumbnailInfo: thumbnailInfo?.toModel(),
            w: w,
            h: h,
            duration: duration,
            size: size,
            mimetype: mimetype,
            localURL: localPath != nil ? URL(fileURLWithPath: localPath!) : nil,
            progress: progress
        )
    }
}

class MediaThumbnailEntity: EmbeddedObject {
    @Persisted var mimetype: String?
    @Persisted var size: Int?
    @Persisted var w: Int?
    @Persisted var h: Int?

    convenience init(from model: MediaThumbnail) {
        self.init()
        self.mimetype = model.mimetype
        self.size = model.size
        self.w = model.w
        self.h = model.h
    }

    func toModel() -> MediaThumbnail {
        return MediaThumbnail(
            mimetype: mimetype,
            size: size,
            w: w,
            h: h
        )
    }
}

final class DBManager: DBManageable {
    static let shared: DBManageable = DBManager()
    private let queue = DispatchQueue(label: "db.realm.serial")
    private var roomHydrationToken: NotificationToken?
    private let roomHydrationSubject = PassthroughSubject<[RoomHydrationPayload], Never>()

    private init() {
        setupRealmConfiguration()
    }

    func makeRealm() -> Realm {
        try! Realm()
    }
    
    // MARK: - Realm Configuration

    private static var config: Realm.Configuration = {
        var c = Realm.Configuration.defaultConfiguration
        // hot safety margin; tune later
        c.maximumNumberOfActiveVersions = 64
        c.shouldCompactOnLaunch = { total, used in
            // compact aggressively if > 100MB and < 60% used
            return (total > 100 * 1024 * 1024) && (Double(used) / Double(total) < 0.6)
        }
        return c
    }()
    
    // Return a NEW Realm for the current thread each time.
    var realm: Realm { try! Realm(configuration: DBManager.config) }

    // Open, run work, and invalidate. This can throw even if the closure doesn't.
    func withRealm<T>(_ work: (Realm) throws -> T) throws -> T {
        let r = try Realm(configuration: DBManager.config)
        defer { r.invalidate() }
        return try work(r)
    }
    
    // Single-transaction helper. This can throw from opening Realm or writing.
    func write(_ block: (Realm) throws -> Void,
               withoutNotifying tokens: [NotificationToken] = []) throws {
        try withRealm { realm in
            try realm.write {
                try block(realm)
            }
        }
    }
    
    func write(_ block: (Realm) throws -> Void) throws {
        try write(block, withoutNotifying: [])
    }
    
    private func setupRealmConfiguration() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("yalchat.realm")
        
        var config = Realm.Configuration(
            fileURL: fileURL,
            schemaVersion: 2,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    // Nothing to do, Realm will automatically add the new property.
                }
            }
        )
        config.maximumNumberOfActiveVersions = 64
        Realm.Configuration.defaultConfiguration = config
    }
    
    // MARK: — Contact CRUD
    
    func saveContacts(contacts: [ContactLite]) {
        guard !contacts.isEmpty else { return }
        let r = realm

        // Pure (non-throwing) merge body
        let performMerge: () -> Void = {
            var seen = Set<String>()
            seen.reserveCapacity(contacts.count)

            for c in contacts {
                guard !c.id.isEmpty, seen.insert(c.id).inserted else { continue }

                if let existing = r.object(ofType: ContactObject.self, forPrimaryKey: c.id) {
                    // ---- MERGE only with meaningful incoming values ----
                    if !(c.fullName ?? "").isEmpty, existing.fullName != c.fullName {
                        existing.fullName = c.fullName
                    }
                    if !c.phoneNumber.isEmpty, existing.phoneNumber != c.phoneNumber {
                        existing.phoneNumber = c.phoneNumber
                    }
                    if let uid = c.userId, !uid.isEmpty {
                        let f = uid.formattedMatrixUserId
                        if existing.userId != f { existing.userId = f }
                    }
                    if let dn = c.displayName, !dn.isEmpty, existing.displayName != dn {
                        existing.displayName = dn
                    }
                    if let imgURL = c.imageURL, !imgURL.isEmpty, existing.imageURL != imgURL {
                        existing.imageURL = imgURL
                    }
                    if let ava = c.avatarURL, !ava.isEmpty, existing.avatarURL != ava {
                        existing.avatarURL = ava
                    }
                    if let msg = c.about, !msg.isEmpty, existing.statusMessage != msg {
                        existing.statusMessage = msg
                    }
                    if let ls = c.lastSeen, ls != existing.lastSeen {
                        existing.lastSeen = ls
                    }
                    // (Optional) If ContactObject has isOnline, set it here
                    // if let online = c.isOnline, existing.isOnline != online {
                    //     existing.isOnline = online
                    // }
                    // Keep any flags you track (e.g., isSynced) if needed.
                    existing.isSynced = existing.isSynced || c.isSynced  // if you add one to ContactLite
                } else {
                    let obj = ContactObject()
                    obj.id          = c.id
                    obj.userId      = (c.userId ?? "").isEmpty ? nil : c.userId?.formattedMatrixUserId
                    obj.fullName    = c.fullName
                    obj.phoneNumber = c.phoneNumber
                    obj.displayName = c.displayName
                    obj.imageURL    = c.imageURL
                    obj.avatarURL   = c.avatarURL
                    obj.statusMessage = c.about
                    obj.lastSeen    = c.lastSeen ?? 0
                    //obj.isOnline  = c.isOnline ?? false
                    r.add(obj, update: .modified) // resilient to races
                }
            }
        }

        do {
            if r.isInWriteTransaction {
                performMerge()
            } else {
                try r.write { performMerge() }
            }
        } catch {
            print("saveContactsLite failure: \(error.localizedDescription)")
        }
    }
    
    func saveContact(contact: ContactLite) {
        saveContacts(contacts: [contact])
    }
    
    func fetchContacts() -> [ContactLite]? {
        let objs = realm.objects(ContactObject.self)
        return objs.map { o in
            var lite = ContactLite(
                userId: o.userId ?? "",
                fullName: o.fullName ?? "",
                phoneNumber: o.phoneNumber,
                emailAddresses: (try? JSONDecoder().decode([String].self, from: o.emailData ?? Data())) ?? [],
                imageURL: o.imageURL,
                avatarURL: o.avatarURL,
                displayName: o.displayName,
                about: o.statusMessage,
                dob: o.dob,
                gender: o.gender,
                profession: o.profession,
                isBlocked: o.isBlocked,
                isSynced: o.isSynced,
                isOnline: false,
                lastSeen: o.lastSeen
            )
            
            return lite
        }
    }
    
    func fetchContact(userId: String) -> ContactLite? {
        let realm = self.realm
        guard let obj = realm.objects(ContactObject.self)
            .filter("userId == %@", userId)
            .first else { return nil }
        
        let contactLite = ContactLite(
            userId: obj.userId ?? "",
            fullName: obj.fullName ?? "",
            phoneNumber: obj.phoneNumber,
            emailAddresses: (try? JSONDecoder().decode([String].self, from: obj.emailData ?? Data())) ?? [],
            avatarURL: obj.avatarURL,
            displayName: obj.displayName,
            about: obj.statusMessage,
            dob: obj.dob,
            gender: obj.gender,
            profession: obj.profession,
            isBlocked: obj.isBlocked,
            isSynced: obj.isSynced
        )
        return contactLite
    }
    
    func updateContact(userId: String, phoneNumber: String?, fullName: String?) {
        let r = realm
        guard let obj = r.object(ofType: ContactObject.self, forPrimaryKey: userId) else { return }
        autoreleasepool {
            try? r.write {
                if let pn = phoneNumber { obj.phoneNumber = pn }
                if let fn = fullName   { obj.fullName   = fn }
            }
        }
    }
    
    func update(contacts: [ContactModel]) {
        guard !contacts.isEmpty else { return }
        let r = realm

        // if you're calling this from background often, wrapping in autoreleasepool is fine
        autoreleasepool {
            do {
                if r.isInWriteTransaction {
                    applyUpdates(contacts, in: r)
                } else {
                    try r.write {
                        applyUpdates(contacts, in: r)
                    }
                }
            } catch {
                print("Contact update failed: \(error)")
            }
        }
    }

    func upsertContactPresence(
        userId: String,
        phoneNumber: String?,
        currentlyActive: Bool?,
        lastActiveAgoMs: Int?,
        avatarURL: String?,
        statusMessage: String?
    ) {
        let key = userId.formattedMatrixUserId
        guard !key.isEmpty, let phoneNumber else { return }

        let r = realm

        do {
            try r.write {
                let obj = r.object(ofType: ContactObject.self, forPrimaryKey: phoneNumber) ?? {
                    let o = ContactObject()
                    o.id = phoneNumber
                    o.userId = key
                    o.phoneNumber = phoneNumber
                    r.add(o, update: .modified)
                    return o
                }()

                if let ts = lastActiveAgoMs {
                    obj.lastSeen = ts
                }

                if let ava = avatarURL, !ava.isEmpty, obj.avatarURL != ava {
                    obj.avatarURL = ava
                }
                if let msg = statusMessage, !msg.isEmpty, obj.statusMessage != msg {
                    obj.statusMessage = msg
                }
            }
        } catch {
            print("upsertContactPresence failure: \(error.localizedDescription)")
        }
    }
    private func applyUpdates(_ contacts: [ContactModel], in r: Realm) {
        for m in contacts {
            // prefer lookup by primary key if you have it
            // if your ContactObject primary key is `id`, do this first
            var contactObject: ContactObject?

            if !m.id.isEmpty {
                contactObject = r.object(ofType: ContactObject.self, forPrimaryKey: m.id)
            }

            if contactObject == nil, let uid = m.userId, !uid.isEmpty {
                // fallback lookup by userId
                contactObject = r.objects(ContactObject.self)
                    .filter("userId == %@", uid.formattedMatrixUserId)
                    .first
            }

            guard let obj = contactObject else {
                // if you want, you can insert here instead of skipping
                continue
            }

            // ---- MERGE only meaningful incoming values ----
            // name
            if let fullName = m.fullName, !fullName.isEmpty, obj.fullName != fullName {
                obj.fullName = m.fullName
            }

            // display name
            if let dn = m.displayName, !dn.isEmpty, obj.displayName != dn {
                obj.displayName = dn
            }

            // phone
            if !m.phoneNumber.isEmpty, obj.phoneNumber != m.phoneNumber {
                obj.phoneNumber = m.phoneNumber
            }

            // userId
            if let uid = m.userId, !uid.isEmpty {
                let formatted = uid.formattedMatrixUserId
                if obj.userId != formatted {
                    obj.userId = formatted
                }
            }

            // avatar / imageURL (prefer non-empty)
            if let url = m.imageURL, !url.isEmpty, obj.imageURL != url {
                obj.imageURL = url
            }
            if let avatar = m.avatarURL, !avatar.isEmpty, obj.avatarURL != avatar {
                obj.avatarURL = avatar
            }

            // imageData
            if let data = m.imageData, !data.isEmpty, data != obj.imageData {
                obj.imageData = data
            }

            // emails
            if let emailData = try? JSONEncoder().encode(m.emailAddresses),
               !emailData.isEmpty,
               emailData != obj.emailData {
                obj.emailData = emailData
            }

            // status message
            if let status = m.statusMessage, !status.isEmpty, obj.statusMessage != status {
                obj.statusMessage = status
            }

            // dob
            if let dob = m.dob, obj.dob != dob {
                obj.dob = dob
            }

            // gender
            if let gender = m.gender, !gender.isEmpty, obj.gender != gender {
                obj.gender = gender
            }

            // profession
            if let profession = m.profession, !profession.isEmpty, obj.profession != profession {
                obj.profession = profession
            }

            // lastSeen — usually you only want to move it forward
            if let incomingLastSeen = m.lastSeen {
                if let existingLastSeen = obj.lastSeen {
                    if incomingLastSeen > existingLastSeen {
                        obj.lastSeen = incomingLastSeen
                    }
                } else {
                    obj.lastSeen = incomingLastSeen
                }
            }

            // synced flag — keep true if either side is true
            obj.isSynced = obj.isSynced || m.isSynced
        }
    }
    
    func deleteContactByPhoneNumber(phoneNumber: String) {
        let r = realm
        let toDel = r.objects(ContactObject.self)
            .filter("phoneNumber == %@", phoneNumber)
        autoreleasepool {
            try? r.write { r.delete(toDel) }
        }
    }
    
    // MARK: — Room CRUD
    func saveRoomSummary(_ summary: RoomSummaryModel) {
        queue.async {
            let realm = self.realm
            
            autoreleasepool {
                do {
                    try realm.write {
                        // If object exists, update it in place
                        if let existing = realm.object(ofType: RoomSummaryObject.self, forPrimaryKey: summary.id) {
                            existing.name = summary.name
                            existing.creator = summary.creator
                            existing.currentUser = try? JSONEncoder().encode(summary.currentUserId)
                            existing.avatarUrl = summary.avatarUrl
                            existing.lastMessage = summary.lastMessage
                            existing.lastMessageType = summary.lastMessageType
                            existing.lastSender  = summary.lastSender
                            existing.unreadCount = summary.unreadCount
                            existing.numberOfParticipants = summary.participantsCount
                            existing.serverTimestamp      = summary.serverTimestamp
                            existing.lastServerTimestamp  = summary.lastServerTimestamp
                            existing.isLeft = summary.isLeft
                            
                            existing.joinedMembersData  = try? JSONEncoder().encode(summary.joinedUserIds)
                            existing.invitedMembersData = try? JSONEncoder().encode(summary.invitedUserIds)
                            existing.leftMembersData    = try? JSONEncoder().encode(summary.leftUserIds)
                            existing.bannedMembersData  = try? JSONEncoder().encode(summary.bannedUserIds)
                            existing.adminData = try? JSONEncoder().encode(summary.adminIds)
                            existing.opponentUserData = try? JSONEncoder().encode(summary.opponentUserId)
                            // Realm auto-updates existing object, no need to re-add
                        } else {
                            // Create new one with primary key BEFORE add()
                            let new = RoomSummaryObject()
                            new.id = summary.id
                            new.name = summary.name
                            new.creator = summary.creator
                            new.currentUser = try? JSONEncoder().encode(summary.currentUserId)
                            new.createdAt = summary.createdAt
                            new.avatarUrl = summary.avatarUrl
                            new.lastMessage = summary.lastMessage
                            new.lastMessageType = summary.lastMessageType
                            new.lastSender  = summary.lastSender
                            new.unreadCount = summary.unreadCount
                            new.numberOfParticipants = summary.participantsCount
                            new.serverTimestamp      = summary.serverTimestamp
                            new.lastServerTimestamp  = summary.lastServerTimestamp
                            new.isLeft = summary.isLeft
                            
                            new.joinedMembersData  = try? JSONEncoder().encode(summary.joinedUserIds)
                            new.invitedMembersData = try? JSONEncoder().encode(summary.invitedUserIds)
                            new.leftMembersData    = try? JSONEncoder().encode(summary.leftUserIds)
                            new.bannedMembersData  = try? JSONEncoder().encode(summary.bannedUserIds)
                            new.adminData = try? JSONEncoder().encode(summary.adminIds)
                            
                            realm.add(new, update: .modified)
                        }
                    }
                } catch {
                    print("[DB] saveRoomSummary error: \(error)")
                }
            }
        }
    }
    
    /// Build a previous RoomSummaryModel snapshot from RoomObject, if present.
    func loadRoomSummary(roomId: String) -> RoomSummaryModel? {
        let r = realm
        guard let o = r.object(ofType: RoomObject.self, forPrimaryKey: roomId) else { return nil }
        
        let currentUser = (try? JSONDecoder().decode(ContactModel.self, from: o.currentUser ?? Data()))
        let admins  = (try? JSONDecoder().decode([String].self, from: o.adminData ?? Data())) ?? []
        let joined  = (try? JSONDecoder().decode([String].self, from: o.joinedMembersData ?? Data())) ?? []
        let invited = (try? JSONDecoder().decode([String].self, from: o.invitedMembersData ?? Data())) ?? []
        let left    = (try? JSONDecoder().decode([String].self, from: o.leftMembersData ?? Data())) ?? []
        let banned  = (try? JSONDecoder().decode([String].self, from: o.bannedMembersData ?? Data())) ?? []
        
        let participantsCount = Set(joined).union(invited).union(left).union(banned).count
        let isGroup = participantsCount > 2
        
        return RoomSummaryModel(
            id: o.id,
            currentUserId: currentUser?.userId ?? "",
            name: o.name,
            avatarUrl: o.avatarUrl,
            lastMessage: o.lastMessage,
            lastMessageType: o.lastMessageType,
            lastSender: o.lastSender,
            lastSenderName: o.lastSenderName,
            unreadCount: o.unreadCount,
            participantsCount: participantsCount,
            serverTimestamp: o.serverTimestamp,
            lastServerTimestamp: o.lastServerTimestamp,
            creator: o.creator,
            createdAt: o.createdAt,
            isLeft: o.isLeft,
            isGroup: isGroup,
            adminIds: admins,
            admins: [],
            joinedUserIds: joined,
            invitedUserIds: invited,
            leftUserIds: left,
            bannedUserIds: banned,
            opponentUserId: nil,
            joinedMembers: [],
            invitedMembers: [],
            leftMembers: [],
            bannedMembers: [],
            participants: []
        )
    }
    
    func fetchRooms() -> [RoomSummaryModel]? {
        let realm = self.realm

        // Use projection so the heavy Data fields are not touched
        let cards = realm.objects(RoomCardProjection.self)

        var rooms: [RoomSummaryModel] = []
        rooms.reserveCapacity(cards.count)

        var existingIds = Set<String>()
        existingIds.reserveCapacity(cards.count)

        // LIGHT path (no member decoding)
        for c in cards {
            rooms.append(
                RoomSummaryModel(
                    id: c.id,
                    currentUserId: "",
                    name: c.name,
                    avatarUrl: c.avatarUrl,
                    lastMessage: c.lastMessage,
                    lastMessageType: c.lastMessageType,
                    lastSender: nil,
                    lastSenderName: c.lastSenderName,
                    unreadCount: c.unreadCount,
                    participantsCount: c.numberOfParticipants,
                    serverTimestamp: c.serverTimestamp,
                    lastServerTimestamp: c.serverTimestamp,
                    creator: "",
                    createdAt: nil,
                    isLeft: false,
                    isGroup: c.numberOfParticipants > 2,
                    adminIds: [],
                    admins: [],
                    joinedUserIds: [],
                    invitedUserIds: [],
                    leftUserIds: [],
                    bannedUserIds: [],
                    opponentUserId: nil,
                    joinedMembers: [],
                    invitedMembers: [],
                    leftMembers: [],
                    bannedMembers: [],
                    participants: []
                )
            )
            existingIds.insert(c.id)
        }

        // Fallback summaries also as a light pass (if you really need them)
        let summaryObjects = realm.objects(RoomSummaryObject.self)
            .filter("NOT (id IN %@)", existingIds)

        for s in summaryObjects {
            rooms.append(
                RoomSummaryModel(
                    id: s.id,
                    currentUserId: "",
                    name: s.name,
                    avatarUrl: s.avatarUrl,
                    lastMessage: s.lastMessage,
                    lastMessageType: s.lastMessageType,
                    lastSender: nil,
                    lastSenderName: s.lastSenderName,
                    unreadCount: s.unreadCount,
                    participantsCount: s.numberOfParticipants,
                    serverTimestamp: s.serverTimestamp,
                    lastServerTimestamp: s.lastServerTimestamp,
                    creator: "",
                    createdAt: nil,
                    isLeft: false,
                    isGroup: s.numberOfParticipants > 2,
                    adminIds: [],
                    admins: [],
                    joinedUserIds: [],
                    invitedUserIds: [],
                    leftUserIds: [],
                    bannedUserIds: [],
                    opponentUserId: nil,
                    joinedMembers: [],
                    invitedMembers: [],
                    leftMembers: [],
                    bannedMembers: [],
                    participants: []
                )
            )
        }

        return rooms
    }
    
    /// Streams RoomModel in batches so the UI can progressively render rooms without freezing.
    /// - Parameters:
    ///   - batchSize: how many rooms per emission
    ///   - sortKey: Realm key to sort by (default: "serverTimestamp")
    ///   - ascending: sort order (default: false => newest first)
    ///   - limit: optional cap on total rooms to emit
    /// - Returns: A publisher emitting `[RoomModel]` batches on the main thread.
    // Emits batches of hydration payloads OFF-MAIN.
    // Caller chooses threads with .subscribe(on:) / .receive(on:)

    func streamRoomHydrations(
        sortKey: String = "serverTimestamp",
        ascending: Bool = false,
        limit: Int? = nil,
        batchSize: Int = 25,
        batchDelay: TimeInterval = 0
    ) -> AnyPublisher<[RoomHydrationPayload], Never> {

        let subject = PassthroughSubject<[RoomHydrationPayload], Never>()

        // keep notification token alive
        final class TokenBox {
            var token: NotificationToken?
        }
        let box = TokenBox()

        // we must add the notification on a runloop thread
        DispatchQueue.main.async {
            // IMPORTANT: open a fresh Realm here (don’t reuse a cross-thread one)
            let realm = try! Realm()
            let results = realm.objects(RoomObject.self)
                .sorted(byKeyPath: sortKey, ascending: ascending)

            print("Room objects count: \(results.count)")

            box.token = results.observe { [self] change in
                switch change {

                // first time → we can send everything
                case .initial(let collection):
                    // copy OUT of Realm immediately so we don't hold this version
                    let rawRooms: [RawRoomSnapshot] = collection.map { RawRoomSnapshot(from: $0) }
                    processRawRooms(
                        rawRooms,
                        limit: limit,
                        batchSize: batchSize,
                        batchDelay: batchDelay,
                        subject: subject
                    )

                // later updates → only inserted/modified
                case .update(let collection, let deletions, let insertions, let modifications):
                    // we don't care about deletions for hydration
                    var changed: [RawRoomSnapshot] = []
                    changed.reserveCapacity(insertions.count + modifications.count)

                    for idx in insertions {
                        let obj = collection[idx]
                        changed.append(RawRoomSnapshot(from: obj))
                    }
                    for idx in modifications {
                        let obj = collection[idx]
                        changed.append(RawRoomSnapshot(from: obj))
                    }

                    guard !changed.isEmpty else { return }

                    processRawRooms(
                        changed,
                        limit: limit,
                        batchSize: batchSize,
                        batchDelay: batchDelay,
                        subject: subject
                    )

                case .error(let err):
                    print("streamRoomHydrations Realm error: \(err)")
                }
            }
        }

        return subject
            .handleEvents(receiveCancel: {
                box.token?.invalidate()
                box.token = nil
            })
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .eraseToAnyPublisher()
    }

    /// A plain, non-Realm, non-frozen snapshot of a RoomObject.
    /// Only simple types / Data here.
    private struct RawRoomSnapshot {
        let id: String
        let creator: String?
        let createdAt: Int64
        let avatarUrl: String?
        let lastMessage: String?
        let lastMessageType: String?
        let lastSender: String?
        let lastSenderName: String?
        let unreadCount: Int
        let currentUserData: Data?
        let joinedData: Data?
        let invitedData: Data?
        let leftData: Data?
        let bannedData: Data?
        let adminsData: Data?
        let stateData: Data?
        let serverTimestamp: Int64?
        let lastServerTimestamp: Int64?

        init(from o: RoomObject) {
            self.id = o.id
            self.creator = o.creator
            self.createdAt = o.createdAt ?? 0
            self.avatarUrl = o.avatarUrl
            self.lastMessage = o.lastMessage
            self.lastMessageType = o.lastMessageType
            self.lastSender = o.lastSender
            self.lastSenderName = o.lastSenderName
            self.unreadCount = o.unreadCount
            self.currentUserData = o.currentUser
            self.joinedData = o.joinedMembersData
            self.invitedData = o.invitedMembersData
            self.leftData = o.leftMembersData
            self.bannedData = o.bannedMembersData
            self.adminsData = o.adminData
            self.stateData = o.state
            self.serverTimestamp = o.serverTimestamp
            self.lastServerTimestamp = o.lastServerTimestamp
        }
    }

    /// heavy work off-main, using *copied* data so Realm can advance versions
    private func processRawRooms(
        _ rawRooms: [RawRoomSnapshot],
        limit: Int?,
        batchSize: Int,
        batchDelay: TimeInterval,
        subject: PassthroughSubject<[RoomHydrationPayload], Never>
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let decoder = JSONDecoder()
            var sent = 0
            var batch: [RoomHydrationPayload] = []
            batch.reserveCapacity(batchSize)

            for raw in rawRooms {
                if let limit, sent >= limit { break }

                // now it's safe to decode; no Realm refs here
                let currentUser = raw.currentUserData.flatMap { try? decoder.decode(String.self, from: $0) }
                let joined      = raw.joinedData.flatMap { try? decoder.decode([String].self, from: $0) } ?? []
                let invited     = raw.invitedData.flatMap { try? decoder.decode([String].self, from: $0) } ?? []
                let left        = raw.leftData.flatMap { try? decoder.decode([String].self, from: $0) } ?? []
                let banned      = raw.bannedData.flatMap { try? decoder.decode([String].self, from: $0) } ?? []
                let admins      = raw.adminsData.flatMap { try? decoder.decode([String].self, from: $0) } ?? []
                let events      = raw.stateData.flatMap { try? decoder.decode([Event].self, from: $0) } ?? []

                batch.append(
                    RoomHydrationPayload(
                        id: raw.id,
                        currentUser: currentUser,
                        creator: raw.creator,
                        createdAt: raw.createdAt,
                        avatarUrl: raw.avatarUrl,
                        lastMessage: raw.lastMessage,
                        lastMessageType: raw.lastMessageType,
                        lastSender: raw.lastSender,
                        lastSenderName: raw.lastSenderName,
                        unreadCount: raw.unreadCount,
                        joinedMembers: joined,
                        invitedMembers: invited,
                        leftMembers: left,
                        bannedMembers: banned,
                        admins: admins,
                        stateEvents: events,
                        serverTimestamp: raw.serverTimestamp,
                        lastServerTimestamp: raw.lastServerTimestamp
                    )
                )

                sent += 1

                if batch.count == batchSize {
                    subject.send(batch)
                    batch.removeAll(keepingCapacity: true)

                    if batchDelay > 0 {
                        Thread.sleep(forTimeInterval: batchDelay)
                    }
                }
            }

            if !batch.isEmpty {
                subject.send(batch)
            }
        }
    }
    
    func updateRoom(
        roomId: String,
        name: String?,
        joinedMembers: [ContactModel]?,
        invitedMembers: [ContactModel]? = nil,
        leftMembers: [ContactModel]? = nil,
        lastMessage: String?,
        lastMessageType: String?,
        lastSender: String?,
        unreadCount: Int?
    ) {
        let r = realm
        guard let o = r.object(ofType: RoomObject.self, forPrimaryKey: roomId) else { return }
        autoreleasepool {
            try? r.write {
                if let n  = name        { o.name        = n }
                if let jMembers = joinedMembers { o.joinedMembersData = try? JSONEncoder().encode(jMembers) }
                if let lMembers = leftMembers { o.leftMembersData = try? JSONEncoder().encode(lMembers) }
                if let iMembers = invitedMembers { o.invitedMembersData =  try? JSONEncoder().encode(iMembers) }
                if let lm = lastMessage { o.lastMessage = lm }
                if let lmt = lastMessageType { o.lastMessageType = lmt }
                if let ls = lastSender  { o.lastSender  = ls }
                if let uc = unreadCount { o.unreadCount = uc }
            }
            
        }
    }
    
    func deleteRoomById(roomId: String) {
        let r = realm
        let toDel = r.objects(RoomSummaryObject.self)
            .filter("id == %@", roomId)
        try? r.write { r.delete(toDel) }
    }
    
    // MARK: — RoomSync
    
    func fetchRoomSync() -> RoomSyncObject? {
        return realm.object(ofType: RoomSyncObject.self, forPrimaryKey: "global")
    }
    
    func saveRoomSync(nextBatch: String) {
        queue.async { [self] in
            let r = realm
            autoreleasepool {
                try? r.write {
                    let obj = RoomSyncObject(value: ["id":"global","nextBatch": nextBatch])
                    r.add(obj, update: .modified)
                }
            }
        }
    }
    
    // MARK: — MessageSync
    
    func countMessages(inRoom roomId: String) -> Int {
        let realm = realm
        return realm.objects(MessageObject.self).filter("roomId == %@", roomId).count
    }
    
    func fetchMessageSync(for roomId: String) -> MessageSyncObject? {
        queue.sync {
            autoreleasepool {
                let r = realm
                guard let obj = r.object(ofType: MessageSyncObject.self, forPrimaryKey: roomId) else { return nil }
                return obj
            }
        }
    }
    
    func fetchAllMessageSyncs() -> [MessageSyncObject] {
        return Array(realm.objects(MessageSyncObject.self))
    }
    
    func saveMessageSync(roomId: String, firstEvent: String?, lastEvent: String?) {
        guard firstEvent != nil || lastEvent != nil else { return }

        queue.sync { [self] in
            autoreleasepool {
                let r = realm // ensure this Realm is created/bound to `queue`, or open a fresh one here
                try? r.write {
                    // fetch or create once
                    let obj = r.object(ofType: MessageSyncObject.self, forPrimaryKey: roomId)
                        ?? MessageSyncObject(value: ["roomId": roomId])

                    if let firstEvent = firstEvent { obj.firstEvent = firstEvent }
                    if let lastEvent  = lastEvent  { obj.lastEvent  = lastEvent  }

                    r.add(obj, update: .modified) // single upsert
                }
            }
        }
    }
    
    // MARK: — Messages
    
    func saveMessage(message: ChatMessageModel, inRoom roomId: String, inReplyTo replyToEventId: String? = nil) {
        queue.async { [self] in
            let r = realm
            autoreleasepool {
                try? r.write {
                    let obj = MessageObject()
                    obj.eventId       = message.eventId
                    obj.roomId        = roomId
                    obj.sender        = message.sender
                    obj.content       = message.content
                    obj.timestamp     = message.timestamp
                    obj.msgType       = message.msgType
                    obj.thumbnailUrl  = message.mediaInfo?.thumbnailUrl
                    obj.mediaSize     = Int(message.mediaInfo?.size ?? 0)
                    obj.currentUserId = message.currentUserId
                    obj.mediaUrl      = message.mediaUrl
                    obj.receipts      = try? JSONEncoder().encode(message.receipts)
                    obj.messageStatus = message.messageStatus.rawValue
                    obj.inReplyTo     = replyToEventId
                    
                    obj.reactions.removeAll()
                    for reaction in message.reactions {
                        let newObject = MessageReactionObject()
                        newObject.eventId = reaction.eventId
                        newObject.userId = reaction.userId
                        newObject.key = reaction.key
                        newObject.timestamp = reaction.timestamp
                        obj.reactions.append(newObject)
                    }
                    
                    r.add(obj, update: .modified)
                }
            }
        }
    }
    
    func saveMessages(messages: [ChatMessageModel], inRoom roomId: String) {
        queue.async { [self] in
            let r = realm
            autoreleasepool {
                try? r.write {
                    for m in messages {
                        if let existing = r.object(ofType: MessageObject.self, forPrimaryKey: m.eventId) {
                            var needsUpdate = false
                            
                            if existing.messageStatus != m.messageStatus.rawValue {
                                existing.messageStatus = m.messageStatus.rawValue
                                needsUpdate = true
                            }

                            let newReceiptsData = try? JSONEncoder().encode(m.receipts)
                            if existing.receipts != newReceiptsData {
                                existing.receipts = newReceiptsData
                                needsUpdate = true
                            }

                            existing.reactions.removeAll()
                            for reaction in m.reactions {
                                let obj = MessageReactionObject()
                                obj.eventId = reaction.eventId
                                obj.userId = reaction.userId
                                obj.key = reaction.key
                                obj.timestamp = reaction.timestamp
                                existing.reactions.append(obj)
                            }
                            needsUpdate = true
                            
                            // Update only if needed
                            if needsUpdate {
                                r.add(existing, update: .modified)
                            }

                        } else {
                            // Message doesn't exist, add it
                            let newMessage = MessageObject(from: m)
                            r.add(newMessage, update: .modified)
                        }
                    }
                }
            }
        }
    }
    
    func fetchMessages(inRoom roomId: String) -> [ChatMessageModel] {
        let r = realm
        let objs = r.objects(MessageObject.self)
            .filter("roomId == %@", roomId)
            .sorted(byKeyPath: "timestamp", ascending: true)
        let messagesArray = Array(objs)
        
        // Build map from eventId → model
        var modelMap: [String: ChatMessageModel] = [:]
        for o in messagesArray {
            let receipts = (try? JSONDecoder().decode([MessageReadReceipt].self, from: o.receipts ?? Data())) ?? []
            
            let reactionModels = o.reactions.map { r in
                MessageReaction(
                    eventId: r.eventId,
                    userId: r.userId,
                    key: r.key,
                    timestamp: r.timestamp
                )
            }
            
            let model = ChatMessageModel(
                eventId:   o.eventId,
                sender:    o.sender,
                content:   o.content,
                timestamp: o.timestamp,
                msgType:   o.msgType,
                mediaUrl:  o.mediaUrl,
                mediaInfo: o.mediaInfo?.toModel(),
                userId:    o.currentUserId ?? o.sender,
                roomId:    o.roomId,
                receipts:  receipts,
                messageStatus: MessageStatus(rawValue: o.messageStatus ?? "sent") ?? .sent,
                inReplyTo: nil, // set below
            )
            model.reactions = Array(reactionModels)
            modelMap[o.eventId] = model
        }
        
        // Second pass: resolve inReplyTo
        for o in messagesArray {
            guard let replyEventId = o.inReplyTo, let model = modelMap[o.eventId] else { continue }
            model.inReplyTo = modelMap[replyEventId]
        }
        
        // Return in original order
        return messagesArray.compactMap { modelMap[$0.eventId] }
    }
    
    func deleteMessage(eventId: String) {
        let r = realm
        let toDel = r.objects(MessageObject.self)
            .filter("eventId == %@", eventId)
        try? r.write { r.delete(toDel) }
    }
    
    func markMessageRedacted(eventId: String) {
        let r = realm
        guard let obj = r.object(ofType: MessageObject.self, forPrimaryKey: eventId) else { return }
        autoreleasepool {
            try? r.write {
                obj.isRedacted = true
                obj.content = thisMessageWasDeleted
                obj.msgType = MessageType.text.rawValue
                obj.mediaUrl = nil
            }
        }
    }
    
    func deleteMessages(inRoom roomId: String) {
        let r = realm
        let toDel = r.objects(MessageObject.self)
            .filter("roomId == %@", roomId)
        try? r.write { r.delete(toDel) }
    }
    
    func deleteAllMessages() {
        let r = realm
        autoreleasepool {
            try? r.write {
                r.delete(r.objects(ContactObject.self))
                r.delete(r.objects(RoomObject.self))
                r.delete(r.objects(RoomSyncObject.self))
                r.delete(r.objects(MessageSyncObject.self))
                r.delete(r.objects(MessageObject.self))
            }
        }
    }
    
    func updateReceipts(forRoom roomId: String, content: EphemeralContent, currentUserId: String) {
        queue.async { [self] in
            guard case let .receipt(receiptContent) = content else { return }
            
            let r = realm
            var updatedEventIds: [String] = []
            
            autoreleasepool {
                try? r.write {
                    for (eventId, receiptEvent) in receiptContent.receipts {
                        guard let targetMessage = r.objects(MessageObject.self)
                            .filter("roomId == %@ AND eventId == %@", roomId, eventId)
                            .first else {
                            print("No targetMessage found for \(eventId)")
                            continue
                        }

                        let targetTimestamp = targetMessage.timestamp

                        let messages = r.objects(MessageObject.self)
                            .filter("roomId == %@ AND timestamp <= %@ AND messageStatus != %@ AND sender == %@",
                                    roomId, targetTimestamp, MessageStatus.read.rawValue, currentUserId)
                            .filter { message in
                                guard let data = message.receipts else {
                                    print("Message \(message.eventId) has no receipts yet — will update")
                                    return true
                                }
                                let existingReceipts = (try? JSONDecoder().decode([MessageReadReceipt].self, from: data)) ?? []
                                return receiptEvent.read?.contains(where: { userId, info in
                                    guard let existing = existingReceipts.first(where: { $0.userId == userId }) else {
                                        print("Missing receipt for user \(userId) in \(message.eventId)")
                                        return true
                                    }
                                    let isOlder = (existing.timestamp ?? 0) < info.ts
                                    //if isOlder {
                                    //    print("Receipt for \(userId) is older in \(message.eventId), updating...")
                                    //}
                                    return isOlder
                                }) ?? false
                            }

                        for message in messages {
                            var receipts: [MessageReadReceipt] = []
                            if let data = message.receipts {
                                receipts = (try? JSONDecoder().decode([MessageReadReceipt].self, from: data)) ?? []
                            }

                            var updated = false

                            receiptEvent.read?.forEach { userId, info in
                                //print("Incoming receipt — user: \(userId), ts: \(info.ts) for event: \(message.eventId)")

                                if let index = receipts.firstIndex(where: { $0.userId == userId }) {
                                    if let oldTS = receipts[index].timestamp, oldTS < info.ts {
                                        //print("Updating existing receipt for \(userId): oldTS=\(oldTS), newTS=\(info.ts)")
                                        receipts[index].timestamp = info.ts
                                        receipts[index].status = .read
                                        updated = true
                                    }
                                } else {
                                    //print("Adding new receipt for user \(userId)")
                                    receipts.append(.init(userId: userId, timestamp: info.ts, status: .read))
                                    updated = true
                                }
                            }

                            if updated {
                                if let updatedData = try? JSONEncoder().encode(receipts) {
                                    message.receipts = updatedData

                                    let allRead = receipts
                                        .filter { $0.userId != currentUserId }
                                        .allSatisfy { $0.status == .read }

                                    if allRead {
                                        //print("All users read \(message.eventId), updating messageStatus to READ")
                                        message.messageStatus = MessageStatus.read.rawValue
                                    } else {
                                        //print("Not all users read \(message.eventId), status remains: \(message.messageStatus ?? "-")")
                                    }

                                    r.add(message, update: .modified)
                                    updatedEventIds.append(message.eventId)
                                } else {
                                    print("Failed to encode receipts for \(message.eventId)")
                                }
                            }
                            r.add(message, update: .modified)
                        }
                    }
                }
            }
        }
    }
    
    func updateMessageStatus(eventId: String, status: MessageStatus) {
        let r = self.realm
        guard let obj = r.object(ofType: MessageObject.self, forPrimaryKey: eventId) else {
            print("No message found with eventId \(eventId) to update status")
            return
        }

        autoreleasepool {
            do {
                try r.write {
                    obj.messageStatus = status.rawValue
                    //print("Updated messageStatus for \(eventId) to \(status.rawValue)")
                    r.add(obj, update: .modified)
                }
            } catch {
                print("Error updating messageStatus: \(error)")
            }
        }
    }
    
    /// Returns the existing ChatMessageModel if present
    func getMessageIfExists(eventId: String) -> ChatMessageModel? {
        let r = self.realm
        guard let obj = r.object(ofType: MessageObject.self, forPrimaryKey: eventId) else { return nil }
        return ChatMessageModel(from: obj, currentUserId: obj.currentUserId ?? obj.sender)
    }

    /// Overwrites the message (or inserts if new)
    func updateMessage(message: ChatMessageModel, inRoom roomId: String, inReplyTo replyToEventId: String? = nil) {
        let r = self.realm
        autoreleasepool {
            try? r.write {
                let obj = MessageObject(from: message)
                obj.roomId = roomId
                obj.inReplyTo = replyToEventId
                r.add(obj, update: .modified)
            }
        }
    }
    
    func addReactionToMessage(
        messageEventId: String,
        reactionEventId: String,
        userId: String,
        emojiKey: String,
        timestamp: Int64
    ) {
        let realm = self.realm
        guard let message = realm.object(ofType: MessageObject.self, forPrimaryKey: messageEventId) else {
            //print("Message not found for reaction: \(messageEventId)")
            return
        }
        autoreleasepool {
            try? realm.write {
                let reaction = MessageReactionObject()
                reaction.eventId = reactionEventId
                reaction.userId = userId
                reaction.key = emojiKey
                reaction.timestamp = timestamp

                // Remove any existing reaction by this user
                if let idx = message.reactions.firstIndex(where: { $0.userId == userId }) {
                    message.reactions.remove(at: idx)
                }
                message.reactions.append(reaction)
                realm.add(message, update: .modified)
            }
        }
    }
    
    // Deletes ALL data in the current Realm. If `purgeFiles` is true,
    // also removes the .realm file + sidecar files on disk.
    func clearAllSync(purgeFiles: Bool = false) {
        let config = Realm.Configuration.defaultConfiguration
        
        // Do work on the DBManager's serial queue to avoid races
        queue.sync {
            autoreleasepool {
                do {
                    let r = try Realm(configuration: config)
                    try r.write { r.deleteAll() }
                    // r is released at the end of the autoreleasepool
                } catch {
                    print("Realm wipe failed: \(error)")
                }
            }
            
            guard purgeFiles, let url = config.fileURL else { return }
            let fm = FileManager.default
            // Common Realm sidecar paths
            let sidecars: [URL] = [
                url,
                url.appendingPathExtension("lock"),
                url.appendingPathExtension("note"),
                url.deletingLastPathComponent()
                    .appendingPathComponent("\(url.lastPathComponent).management", isDirectory: true)
            ]
            for u in sidecars { try? fm.removeItem(at: u) }
        }
    }
}

// MARK: - Full room summaries (heavy decode, optional contact resolution)

extension DBManager {

    // Build 1 full summary (tries RoomObject, then RoomSummaryObject).
    func fetchFullRoomSummary(
        roomId: String,
        includeContacts: Bool = false,
        resolveContact: ((String) -> ContactLite?)? = nil
    ) -> RoomSummaryModel? {
        let r = realm
        if let ro = r.object(ofType: RoomSummaryObject.self, forPrimaryKey: roomId) {
            return makeSummary(fromRoomObject: ro, includeContacts: includeContacts, resolveContact: resolveContact)
        }
        if let so = r.object(ofType: RoomSummaryObject.self, forPrimaryKey: roomId) {
            return makeSummary(fromSummaryObject: so, includeContacts: includeContacts, resolveContact: resolveContact)
        }
        return nil
    }

    func fetchRecentFullRoomSummaries(
        limit: Int? = 50,
        sortKey: String = "serverTimestamp",
        ascending: Bool = false,
        includeContacts: Bool = false,
        resolveContact: ((String) -> ContactLite?)? = nil
    ) -> [RoomSummaryModel] {
        fetchFullRoomSummaries(
            ids: nil,
            limit: limit,
            sortKey: sortKey,
            ascending: ascending,
            includeContacts: includeContacts,
            resolveContact: resolveContact
        )
    }
    
    /// Fetch many full summaries.
    /// - Parameters:
    ///   - ids: restrict to a specific set of roomIds (optional)
    ///   - limit: cap number of results (optional)
    ///   - sortKey: Realm key (on RoomObject) to sort by, default "serverTimestamp"
    ///   - ascending: sort order
    ///   - includeContacts: when true, uses `resolveContact` to materialize ContactModel arrays
    ///   - resolveContact: closure to convert userId → ContactModel (e.g. via ContactManager/DB)
    func fetchFullRoomSummaries(
        ids: [String]? = nil,
        limit: Int? = nil,
        sortKey: String = "serverTimestamp",
        ascending: Bool = false,
        includeContacts: Bool = false,
        resolveContact: ((String) -> ContactLite?)? = nil
    ) -> [RoomSummaryModel] {
        
        let r = realm
        var collected: [RoomSummaryModel] = []
        collected.reserveCapacity(limit ?? 32)
        
        // Prefer RoomObject (richer + freshest)
        var roomResults = r.objects(RoomSummaryObject.self)
        if let ids { roomResults = roomResults.filter("id IN %@", ids) }
        roomResults = roomResults.sorted(byKeyPath: sortKey, ascending: ascending)

        var seenIds = Set<String>()
        for o in roomResults {
            if let lim = limit, collected.count >= lim { break }
            if let summary = makeSummary(fromRoomObject: o, includeContacts: includeContacts, resolveContact: resolveContact) {
                collected.append(summary)
                seenIds.insert(o.id)
            }
        }

        // Fallback to RoomSummaryObject for any not present in RoomObject
        let base = r.objects(RoomSummaryObject.self)
        let summaryQuery: Results<RoomSummaryObject>

        if let ids {
            let missing = ids.filter { !seenIds.contains($0) }
            summaryQuery = missing.isEmpty
            ? base.filter("FALSEPREDICATE")
            : base.filter("id IN %@", missing)
        } else {
            // When ids is nil, include all summaries that are NOT already seen in RoomObject
            summaryQuery = seenIds.isEmpty
            ? base
            : base.filter("NOT id IN %@", Array(seenIds))
        }
        
        // Apply the same sort as RoomObject before iterating:
        let sortedSummary = summaryQuery.sorted(byKeyPath: sortKey, ascending: ascending)
        
        for s in sortedSummary {
            if let lim = limit, collected.count >= lim { break }
            if let summary = makeSummary(
                fromSummaryObject: s,
                includeContacts: includeContacts,
                resolveContact: resolveContact
            ) {
                collected.append(summary)
            }
        }

        return collected
    }

    // MARK: - Builders

    private func makeSummary(
        fromRoomObject o: RoomSummaryObject,
        includeContacts: Bool,
        resolveContact: ((String) -> ContactLite?)?
    ) -> RoomSummaryModel? {
        let decoder = JSONDecoder()

        let currentUserId  = (o.currentUser).flatMap { try? decoder.decode(String.self, from: $0) } ?? ""
        let joinedIds      = (o.joinedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let invitedIds     = (o.invitedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let leftIds        = (o.leftMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let bannedIds      = (o.bannedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let adminIds        = (o.adminData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []

        let allIds = Array(Set(joinedIds + invitedIds + leftIds + bannedIds))
        let isGroup = allIds.count > 2
        let opponentId = isGroup ? nil : allIds.first(where: { $0 != currentUserId && !$0.isEmpty })

        // Optional: resolve ContactModel arrays
        let resolvedJoined: [ContactLite]  = includeContacts ? joinedIds.compactMap { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedInvited: [ContactLite] = includeContacts ? invitedIds.compactMap { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedLeft: [ContactLite]    = includeContacts ? leftIds.compactMap    { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedBanned: [ContactLite]  = includeContacts ? bannedIds.compactMap  { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedAll: [ContactLite]     = includeContacts ? (resolvedJoined + resolvedInvited + resolvedLeft + resolvedBanned) : []
        let admins: [ContactLite]          = includeContacts ? adminIds.compactMap({ resolveContact?($0) ?? self._fallbackResolve($0) }) : []
        
        return RoomSummaryModel(
            id: o.id,
            currentUserId: currentUserId,
            name: o.name,
            avatarUrl: o.avatarUrl,
            lastMessage: o.lastMessage,
            lastMessageType: o.lastMessageType,
            lastSender: o.lastSender,
            lastSenderName: o.lastSenderName,
            unreadCount: o.unreadCount,
            participantsCount: allIds.count,
            serverTimestamp: o.serverTimestamp,
            lastServerTimestamp: o.lastServerTimestamp,
            creator: o.creator,
            createdAt: o.createdAt,
            isLeft: o.isLeft,
            isGroup: isGroup,
            adminIds: adminIds,
            admins: admins,
            joinedUserIds: joinedIds,
            invitedUserIds: invitedIds,
            leftUserIds: leftIds,
            bannedUserIds: bannedIds,
            opponentUserId: opponentId,
            joinedMembers: resolvedJoined,
            invitedMembers: resolvedInvited,
            leftMembers: resolvedLeft,
            bannedMembers: resolvedBanned,
            participants: resolvedAll
        )
    }

    private func makeSummary(
        fromSummaryObject s: RoomSummaryObject,
        includeContacts: Bool,
        resolveContact: ((String) -> ContactLite?)?
    ) -> RoomSummaryModel? {
        let decoder = JSONDecoder()

        let currentUserId  = (s.currentUser).flatMap { try? decoder.decode(String.self, from: $0) } ?? ""
        let joinedIds      = (s.joinedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let invitedIds     = (s.invitedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let leftIds        = (s.leftMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let bannedIds      = (s.bannedMembersData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []
        let adminIds       = (s.adminData).flatMap { try? decoder.decode([String].self, from: $0) } ?? []

        let allIds = Array(Set(joinedIds + invitedIds + leftIds + bannedIds))
        let isGroup = allIds.count > 2
        let opponentId = isGroup ? nil : (s.opponentUserData.flatMap { try? decoder.decode(String.self, from: $0) } ?? allIds.first { $0 != currentUserId })

        // Optional: resolve ContactModel arrays
        let resolvedJoined  = includeContacts ? joinedIds.compactMap { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedInvited = includeContacts ? invitedIds.compactMap { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedLeft    = includeContacts ? leftIds.compactMap    { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedBanned  = includeContacts ? bannedIds.compactMap  { resolveContact?($0) ?? self._fallbackResolve($0) } : []
        let resolvedAll     = includeContacts ? (resolvedJoined + resolvedInvited + resolvedLeft + resolvedBanned) : []
        let admins          = includeContacts ? adminIds.compactMap { resolveContact?($0) ?? self._fallbackResolve($0) } : []

        return RoomSummaryModel(
            id: s.id,
            currentUserId: currentUserId,
            name: s.name,
            avatarUrl: s.avatarUrl,
            lastMessage: s.lastMessage,
            lastMessageType: s.lastMessageType,
            lastSender: s.lastSender,
            lastSenderName: s.lastSenderName,
            unreadCount: s.unreadCount,
            participantsCount: allIds.count,
            serverTimestamp: s.serverTimestamp,
            lastServerTimestamp: s.lastServerTimestamp,
            creator: s.creator,
            createdAt: s.createdAt,
            isLeft: s.isLeft,
            isGroup: isGroup,
            adminIds: adminIds,
            admins: admins,
            joinedUserIds: joinedIds,
            invitedUserIds: invitedIds,
            leftUserIds: leftIds,
            bannedUserIds: bannedIds,
            opponentUserId: opponentId,
            joinedMembers: resolvedJoined,
            invitedMembers: resolvedInvited,
            leftMembers: resolvedLeft,
            bannedMembers: resolvedBanned,
            participants: resolvedAll
        )
    }

    // Default resolver if caller didn't provide one:
    // uses ContactLite from DB and maps to a minimal ContactModel.
    private func _fallbackResolve(_ userId: String) -> ContactLite? {
        guard let lite = fetchContact(userId: userId) else { return nil }
        return ContactLite(
            userId: lite.userId,
            fullName: lite.fullName,
            imageData: nil,
            phoneNumber: lite.phoneNumber,
            emailAddresses: lite.emailAddresses,
            imageURL: lite.imageURL,
            avatarURL: lite.imageURL,
            displayName: lite.displayName,
            about: lite.about,
            dob: lite.dob,
            gender: lite.gender,
            profession: lite.profession,
            isBlocked: lite.isBlocked,
            isSynced: false,
            isOnline: false,
            lastSeen: lite.lastSeen,
            randomeProfileColor: nil
        )
    }
}

extension DBManager {
    
    func backfillRoom(
        roomId: String,
        messages: [ChatMessageModel],
        redactedEventIds: [String],
        reactions: [ReactionRecord]
    ) {
        queue.sync { [self] in
            autoreleasepool {
                do {
                    try write { realm in
                        if !redactedEventIds.isEmpty {
                            let objs = realm.objects(MessageObject.self)
                                .filter("eventId IN %@", redactedEventIds)
                            for o in objs {
                                o.isRedacted = true
                                o.content = thisMessageWasDeleted
                                o.msgType = MessageType.text.rawValue
                                o.mediaUrl = nil
                            }
                        }

                        if !messages.isEmpty {
                            for m in messages {
                                let obj = MessageObject(from: m)
                                obj.roomId = roomId
                                if let replyId = m.inReplyTo?.eventId {
                                    obj.inReplyTo = replyId
                                }
                                realm.add(obj, update: .modified)
                            }
                        }

                        if !reactions.isEmpty {
                            let originals = Array(Set(reactions.map { $0.original }))
                            let existing = realm.objects(MessageObject.self)
                                .filter("eventId IN %@", originals)
                            let byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.eventId, $0) })

                            for item in reactions {
                                guard let target = byId[item.original] else { continue }

                                if let idx = target.reactions.firstIndex(where: { $0.eventId == item.reaction }) {
                                    target.reactions.remove(at: idx)
                                }

                                if let idx = target.reactions.firstIndex(where: { $0.userId == item.userId && $0.key == item.emoji }) {
                                    target.reactions.remove(at: idx)
                                }

                                let r = MessageReactionObject()
                                r.eventId   = item.reaction
                                r.userId    = item.userId
                                r.key       = item.emoji
                                r.timestamp = item.ts
                                target.reactions.append(r)
                            }
                        }
                    }
                } catch {
                    print("[DB] backfillRoom write failed: \(error)")
                }
            }
        }
    }
}
