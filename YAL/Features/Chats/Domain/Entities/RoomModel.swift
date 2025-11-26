//
//  RoomModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/05/25.
//


import Foundation
import Combine
import SwiftUI

enum MembershipStatus: String {
    case join, invite, leave, ban, knock
}

class RoomModel: ObservableObject, Identifiable, Equatable, Hashable {
    var isHydrated: Bool = false
    private var observersAttached = false

    private func setupObserversIfNeeded() {
        guard !observersAttached else { return }
        observersAttached = true
        setupObservers()
    }

    // Assign only when changed to avoid extra objectWillChange sends
    @inline(__always)
    private func setIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<RoomModel,T>, _ newValue: T?) {
        guard let v = newValue else { return }
        if self[keyPath: keyPath] != v { self[keyPath: keyPath] = v }
    }
    
    @inline(__always)
    private func assertMain(_ f: StaticString = #fileID, _ l: UInt = #line) {
        precondition(Thread.isMainThread, "RoomModel must mutate on main (\(f):\(l))")
    }
    
    @inline(__always)
    private func onMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
    
    let id: String
    var currentUserId: String?
    var currentUser: ContactModel?
    @Published var randomeProfileColor: Color = randomBackgroundColor()
    @Published var name: String = ""
    @Published var creator: String = ""
    @Published var createdAt: Int64?
    @Published var lastMessage: String? = ""
    @Published var lastMessageType: String = "m.text"
    @Published var lastSender: String? = "" {
        didSet {
            if isGroup {
                updateLastSenderName()
            }
        }
    }
    @Published var lastSenderName: String? = ""
    @Published var unreadCount: Int = 0
    @Published var participantsCount: Int = 0
    @Published var avatarUrl: String?
    @Published var opponent: ContactModel?
    @Published var isGroup: Bool = false
    @Published var isDeleted: Bool = false
    @Published var isMuted: Bool = false
    @Published var isRead: Bool = false
    @Published var isLocked: Bool = false
    @Published var isBlocked: Bool = false
    @Published var isFavorite: Bool = false
    @Published var typingUsers: [String] = []
    @Published var admins: [ContactModel] = []
    @Published var isLeft: Bool = false
    @Published var joinedMemberIds: [String] = []
    @Published var invitedMemberIds: [String] = []
    @Published var leftMemberIds: [String] = []
    @Published var bannedMemberIds: [String] = []
    @Published var participants: [ContactModel] = []
    @Published var joinedMembers: [ContactModel] = []
    @Published var invitedMembers: [ContactModel] = []
    @Published var leftMembers: [ContactModel] = []
    @Published var bannedMembers: [ContactModel] = []
    @Published var blockedMembers: [String] = []
    
    // Store timeline & summary if you need to update later
    var state: StateEvents?
    var timeline: Timeline?
    var summary: RoomSummary?
    var unreadNotifications: UnreadNotifications?
    var serverTimestamp: Int64?
    var lastServerTimestamp: Int64?
    
    private var cancellables = Set<AnyCancellable>()

    private struct MemberSnapshot {
        var contact: ContactLite
        var status: MembershipStatus
        var ts: Int64 // originServerTs of the membership event we used
    }

    // Single source of truth
    private var memberMap: [String: MemberSnapshot] = [:]
    
    // MARK: - Initializer for cached/snapshot room data (FAST PATH)
    init(
        id: String = "",
        name: String? = nil,
        currentUserId: String? = nil,
        avatarUrl: String? = nil,
        lastMessage: String? = nil,
        lastMessageType: String,
        lastSenderName: String? = nil,
        unreadCount: Int? = nil,
        participantsCount: Int = 0,
        lastServerTimestamp: Int64?,
        joinedMemberIds: [String] = [],
        invitedMemberIds: [String] = [],
        leftMemberIds: [String] = [],
        bannedMemberIds: [String] = []
    ) {
        // Identity / context
        self.id = id
        self.currentUser = getCurrentUserContact()

        // Light display fields
        self.name = name ?? ""
        self.avatarUrl = avatarUrl
        self.lastMessage = lastMessage
        self.lastMessageType = lastMessageType
        self.lastSender = nil
        self.lastSenderName = lastSenderName
        self.unreadCount = unreadCount ?? 0
        self.serverTimestamp = nil
        self.lastServerTimestamp = lastServerTimestamp

        // Meta
        self.creator = ""
        self.createdAt = nil
        self.isLeft = false

        // Participants (keep empty in snapshot)
        self.joinedMemberIds = joinedMemberIds
        self.invitedMemberIds = invitedMemberIds
        self.leftMemberIds = leftMemberIds
        self.bannedMemberIds = bannedMemberIds
        
        // Seed SoT once from provided arrays
//        seedMemberMapFromCachedMembers(
//            joined: joinedMemberIds,
//            invited: invitedMemberIds,
//            left: leftMemberIds,
//            baselineTS: serverTimestamp ?? createdAt
//        )
        
        self.participants = []
        self.participantsCount = participantsCount
        self.isGroup = participantsCount > 2
        self.admins = []

        // Matrix state placeholders
        self.state = nil
        self.timeline = nil
        self.summary = nil
        self.unreadNotifications = nil

        // Snapshot stays LIGHT: no observers, no memberMap seeding
        self.randomeProfileColor = randomBackgroundColor()
        self.isHydrated = false
        setupObserversIfNeeded()
    }
    
    // MARK: - Initializer for full/hydrated room data (HEAVY PATH)
    init(
        id: String = "",
        name: String? = nil,
        currentUser: ContactModel? = nil,
        creator: String? = nil,
        createdAt: Int64? = nil,
        avatarUrl: String? = nil,
        lastMessage: String? = nil,
        lastMessageType: String,
        lastSender: String? = nil,
        lastSenderName: String? = nil,
        unreadCount: Int? = nil,
        participantsCount: Int = 0, // optional hint; will be recomputed
        joinedMembers: [String] = [],
        invitedMembers: [String] = [],
        leftMembers: [String] = [],
        bannedMembers: [String] = [],
        serverTimestamp: Int64?,
        lastServerTimestamp: Int64?,
        admins: [ContactModel] = [],
        isLeft: Bool = false,
        state: [Event]? = nil
    ) {
        // Identity / context
        self.id = id
        self.currentUser = currentUser
        
        // Display/meta
        self.name = name ?? ""
        self.creator = creator ?? ""
        self.createdAt = createdAt
        self.avatarUrl = avatarUrl
        self.lastMessage = lastMessage
        self.lastMessageType = lastMessageType
        self.lastSender = lastSender
        self.lastSenderName = lastSenderName
        self.unreadCount = unreadCount ?? 0
        self.serverTimestamp = serverTimestamp
        self.lastServerTimestamp = lastServerTimestamp
        self.isLeft = isLeft
        
        // Admins
        self.admins = admins
        
        // Matrix state
        self.state = StateEvents(events: state)
        self.timeline = nil
        self.summary = nil
        self.unreadNotifications = nil
        
        // Observers + derived
        setupObserversIfNeeded()
        
        // If snapshot already seeded the map, don't throw it away.
//        if memberMap.isEmpty {
//            let baseline = self.lastServerTimestamp ?? self.serverTimestamp ?? self.createdAt ?? 0
//            seedMemberMapFromCachedMembers(
//                joined: joinedMembers,
//                invited: invitedMembers,
//                left: leftMembers,
//                banned: bannedMembers,
//                baselineTS: baseline
//            )
//        }
        
        if self.admins.isEmpty, self.isGroup {
            self.admins = getAdmins()
        }
        self.isHydrated = true
    }
    
    // MARK: - Hydration API (upgrade snapshot ➜ full)
    func hydrate(
        currentUser: String? = nil,
        creator: String? = nil,
        createdAt: Int64? = nil,
        avatarUrl: String? = nil,
        lastMessage: String? = nil,
        lastSender: String? = nil,
        lastSenderName: String? = nil,
        unreadCount: Int? = nil,
        joinedMembers: [String],
        invitedMembers: [String],
        leftMembers: [String],
        bannedMembers: [String],
        admins: [String] = [],
        stateEvents: [Event] = [],
        serverTimestamp: Int64? = nil,
        lastServerTimestamp: Int64? = nil
    ) {
        assertMain()

        setIfChanged(\.currentUserId, currentUser)
        setIfChanged(\.creator, creator)
        setIfChanged(\.createdAt, createdAt)
        setIfChanged(\.avatarUrl, avatarUrl)       // snapshot avatar may already be correct
        setIfChanged(\.lastMessage, lastMessage)
        setIfChanged(\.lastSender, lastSender)
        setIfChanged(\.lastSenderName, lastSenderName)
        setIfChanged(\.unreadCount, unreadCount)
        setIfChanged(\.serverTimestamp, serverTimestamp)
        setIfChanged(\.lastServerTimestamp, lastServerTimestamp)
        
        self.currentUser = getCurrentUserContact()

        // State
        if !stateEvents.isEmpty {
            self.state = StateEvents(events: stateEvents)
        }

        // Build SoT and observers (idempotent)
//        seedMemberMapFromCachedMembers(
//            joined: joinedMembers,
//            invited: invitedMembers,
//            left: leftMembers,
//            banned: bannedMembers,
//            baselineTS: self.serverTimestamp ?? self.createdAt
//        )

        // Admins (use provided or compute)
        if !admins.isEmpty && self.isGroup {
            self.admins = getAdmins()
        }

        // Fully hydrated now
        self.isHydrated = true
        setupObserversIfNeeded()
    }
    
    init(
        id: String,
        state: StateEvents?,
        timeline: Timeline?,
        summary: RoomSummary?,
        unreadNotifications: UnreadNotifications?,
        currentUser: ContactModel?
    ) {
        self.id = id
        if state?.events?.count ?? 0 > 0 {
            self.state = state
        }
        if let newEvents = timeline?.events {
            self.timeline?.events?.append(contentsOf: newEvents)
        }
        self.summary = summary
        self.unreadNotifications = unreadNotifications
        self.currentUser = currentUser
        
        let stateEvents = state?.events?.sorted { $0.originServerTs ?? 0 > $1.originServerTs ?? 0 }
        let timelineEvets = timeline?.events?.sorted { $0.originServerTs ?? 0 > $1.originServerTs ?? 0 }
        self.serverTimestamp = timelineEvets?.first?.originServerTs ?? 0
        self.lastServerTimestamp = timelineEvets?.last?.originServerTs ?? 0

        // Parse and populate from timeline/summary
        if let roomCreateEvent = stateEvents?.first(where: { $0.type == "m.room.create" }) {
            self.creator = roomCreateEvent.sender ?? ""
            self.createdAt = roomCreateEvent.originServerTs ?? 0
        } else if let roomCreateEvent = timelineEvets?.first(where: { $0.type == "m.room.create" }) {
            self.creator = roomCreateEvent.sender ?? ""
            self.createdAt = roomCreateEvent.originServerTs ?? 0
        }
        
        self.avatarUrl = timelineEvets?.first(where: { $0.type == "m.room.avatar" })?.content?.url
                
        if let lastMessageEvent = timelineEvets?.last(where: { $0.type == "m.room.message" }) {
            self.lastMessage = lastMessageEvent.content?.body
            self.lastSender = lastMessageEvent.sender
            self.lastMessageType = lastMessageEvent.content?.msgType ?? "m.text"
        }
        
        self.unreadCount = unreadNotifications?.notificationCount ?? 0
        
        // Canonical membership update (handles add/remove/move between buckets)
        if let events = stateEvents {
            //applyMembershipEvents(events)
        }
        
        // Set up observers to auto-update isGroup, opponent, joinedMembers, and name
        setupObserversIfNeeded()
        
        // Manual sync to initialize derived properties
        updateMembers(joined: joinedMembers, invited: invitedMembers, left: leftMembers)
        
        if self.isGroup {
            self.admins = self.getAdmins()
        }
    }
    
    // Seed the memberMap once when we restore from cached arrays.
    // baselineTS is used only for ordering; newer first.
//    private func seedMemberMapFromCachedMembers(
//        joined: [String],
//        invited: [String],
//        left: [String],
//        banned: [String] = [],
//        baselineTS: Int64? = nil
//    ) {
//        var ts = baselineTS
//            ?? serverTimestamp
//            ?? createdAt
//            ?? Int64(Date().timeIntervalSince1970 * 1000)
//
//        func step() { ts &-= 1 }
//
//        for c in joined {
//            hydrateAvatar(for: c)
//            upsertMember(userId: c, newStatus: .join, ts: ts)
//            step()
//        }
//        for c in invited {
//            hydrateAvatar(for: c)
//            upsertMember(userId: c, newStatus: .invite, ts: ts)
//            step()
//        }
//        for c in left {
//            hydrateAvatar(for: c)
//            upsertMember(userId: c, newStatus: .leave, ts: ts)
//            step()
//        }
//        //rebuildMemberBucketsFromMap()
//        participants = memberMap.values.map { $0.contact }
//    }
    
    // MARK: - Central update logic for members
    private func updateMembers(joined: [ContactModel], invited: [ContactModel], left: [ContactModel]) {
        let participants = joined + invited + left
        if participants.isEmpty {
            return
        }
        self.participants = participants
        self.participantsCount = self.participants.count
        self.isGroup = self.participantsCount > 2
        
        // opponent logic
        if !isGroup, let currentUserId = self.currentUser?.userId {
            self.opponent = self.participants.first(where: { $0.userId != currentUserId })
        } else {
            self.opponent = nil
        }
        
        // room name logic
        if isGroup {
            let createRoomEvent = self.state?.events?.first(where: { $0.type == "m.room.name" })
            if self.name.isEmpty {
                self.name = createRoomEvent?.content?.name ?? "Group"
            } else if let newName = createRoomEvent?.content?.name {
                self.name = newName
            }
            
            if let avatarEvent = self.state?.events?.first(where: { $0.type == "m.room.avatar" }),
                let avatarUrlString = avatarEvent.content?.url as? String {
                self.avatarUrl = avatarUrlString
            }
        } else if let opponent = self.opponent {
            if let fullName = opponent.fullName, !fullName.isEmpty {
                self.name = fullName
            } else {
                self.name = opponent.phoneNumber
            }
            self.avatarUrl = opponent.avatarURL
        } else {
            self.name = "Chat"
        }
    }
    
    // MARK: - Combine observers
    func setupObservers() {
        Publishers.CombineLatest3($joinedMembers, $invitedMembers, $leftMembers)
            .sink { [weak self] joined, invited, left in
                self?.updateMembers(joined: joined, invited: invited, left: left)
            }
            .store(in: &cancellables)
    }
    
    func update(
        state: StateEvents?,
        timeline: Timeline?,
        summary: RoomSummary?,
        unreadNotifications: UnreadNotifications?
    ) {
        onMain { [weak self] in
            guard let self else { return }
            
            if state?.events?.count ?? 0 > 0 {
                self.state = state
            }
            if let newEvents = timeline?.events {
                self.timeline?.events?.append(contentsOf: newEvents)
            }
            self.summary = summary
            self.unreadNotifications = unreadNotifications
            
            let stateEvents = state?.events?.sorted { $0.originServerTs ?? 0 > $1.originServerTs ?? 0 }
            let timelineEvents = timeline?.events?.sorted { $0.originServerTs ?? 0 > $1.originServerTs ?? 0 }
            self.serverTimestamp = timelineEvents?.first?.originServerTs ?? 0
            self.lastServerTimestamp = timelineEvents?.last?.originServerTs ?? 0
            
            // Update static fields
            if let roomCreateEvent = stateEvents?.first(where: { $0.type == "m.room.create" }) {
                self.creator = roomCreateEvent.sender ?? self.creator
                self.createdAt = roomCreateEvent.originServerTs ?? 0
            } else if let roomCreateEvent = timelineEvents?.first(where: { $0.type == "m.room.create" }) {
                self.creator = roomCreateEvent.sender ?? self.creator
                self.createdAt = roomCreateEvent.originServerTs ?? 0
            }
            
            if isGroup {
                self.name = timelineEvents?.first(where: { $0.type == "m.room.name" })?.content?.name ?? self.name
            }
            
            self.avatarUrl = timelineEvents?.first(where: { $0.type == "m.room.avatar" })?.content?.url ?? self.avatarUrl
            
            if let lastMessageEvent = timelineEvents?.last(where: { $0.type == "m.room.message" }) {
                self.lastMessage = lastMessageEvent.content?.body
                self.lastSender = lastMessageEvent.sender
                self.lastMessageType = lastMessageEvent.content?.msgType ?? "m.text"
            }
            
//            if let events = stateEvents {
//                applyMembershipEvents(events)
//            }
            
//            if let tEvents = timeline?.events {
//                applyMembershipEvents(tEvents.asEvents(roomId: self.id))
//            }
            
            // Update unread count
            self.unreadCount = unreadNotifications?.notificationCount ?? self.unreadCount
            
            if self.isGroup {
                self.admins = self.getAdmins()
            }
        }
    }
    
    private func updateLastSenderName() {
        guard let lastSender = lastSender, !lastSender.isEmpty else {
            lastSenderName = nil
            return
        }
        // Try to find the contact matching the last sender's userId
        if let member = joinedMembers.first(where: { $0.userId == lastSender }) {
            if let fullName = member.fullName, !fullName.isEmpty {
                lastSenderName = fullName
            } else {
                lastSenderName = member.phoneNumber
            }
        } else {
            lastSenderName = "" // fallback to userId if not found
        }
    }
    
    private func getAdmins() -> [ContactModel] {
        // Find the latest power_levels event
        guard let powerEvent = state?.events?.last(where: { $0.type == "m.room.power_levels" }),
              let content = powerEvent.content,
              let usersDict = content.users else {
            return []
        }
        // We can use 50 for "mod", 100 for "admin"
        // Here, let's consider power level ≥ 50 as admin
        let adminIds = usersDict.compactMap { (key, value) -> String? in
            if value >= 50 { return key }
            return nil
        }
        let admins = self.participants.filter { member in
            guard let userId = member.userId else { return false }
            return adminIds.contains(userId)
        }
        return admins
    }
    
    private func status(from raw: String) -> MembershipStatus? {
        MembershipStatus(rawValue: raw)
    }

    private func contact(for userId: String) -> ContactLite {
        // Try your address book first
        if let c = ContactManager.shared.contact(for: userId) { return c }
        // Fallback lightweight ContactModel if missing
        return ContactLite(userId: userId, fullName: "", phoneNumber: "")
    }

    private func upsertMember(userId: String, newStatus: MembershipStatus, ts: Int64) {
        // Only accept if it's newer than what we have
        if let existing = memberMap[userId], existing.ts > ts {
            let contact = self.contact(for: userId)
            let snapshot = MemberSnapshot(contact: contact, status: newStatus, ts: ts)
            memberMap[userId] = snapshot
        } else {
            let contact = self.contact(for: userId)
            let snapshot = MemberSnapshot(contact: contact, status: newStatus, ts: ts)
            memberMap[userId] = snapshot
            DBManager.shared.saveContact(contact: contact)
        }
    }
    
//    private func hydrateAvatar(for userId: String, event: Event? = nil) {
//        let contact = self.contact(for: userId)
//        if let event = event, let avatar = event.content?.avatarUrl, !avatar.isEmpty {
//            contact.avatarURL = avatar
//        } else if contact.avatarURL == nil || contact.avatarURL?.isEmpty == true {
//            // fallback from room.state if exists
//            if let avatarEvent = state?.events?.first(where: { $0.type == "m.room.member" && $0.stateKey == userId }),
//               let avatar = avatarEvent.content?.avatarUrl, !avatar.isEmpty {
//                contact.avatarURL = avatar
//            }
//        }
//    }
    
    func updateLastMessageDetails(with message: String, sender: String?) {
        onMain {
            self.lastMessage = message
            self.lastSender = sender
        }
    }
    
    func getCurrentUserContact() -> ContactModel? {
        if let currentUserData = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self),
           let phoneNumber = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self),
           let profile = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self) {
            let currentUser = ContactModel(
                phoneNumber: phoneNumber,
                userId: currentUserData.userId,
                fullName: profile.name
            )
            return currentUser
        }
        return nil
    }
}

extension RoomModel {
    convenience init(
        roomId: String,
        stateEvents: [Event],
        currentUser: ContactModel?
    ) {
        let state = StateEvents(events: stateEvents)
        let stateEvents = state.events?.sorted { $0.originServerTs ?? 0 > $1.originServerTs ?? 0 }
        let serverTimestamp = stateEvents?.first?.originServerTs ?? 0
        let lastServerTimestamp: Int64 = stateEvents?.last?.originServerTs ?? 0

        let roomCreateEvent = stateEvents?.first(where: { $0.type == "m.room.create" })
        let creator = roomCreateEvent?.sender
        let createdAt = roomCreateEvent?.originServerTs ?? 0
        
        let name = state.events?.first(where: { $0.type == "m.room.name" })?.content?.name ?? ""

        self.init(
            id: roomId,
            name: name,
            currentUser: currentUser,
            creator: creator,
            createdAt: createdAt,
            avatarUrl: nil,
            lastMessage: nil,
            lastMessageType: "",
            lastSender: nil,
            unreadCount: 0,
            serverTimestamp: serverTimestamp,
            lastServerTimestamp: lastServerTimestamp
        )
        
        self.state = state
//        if let events = state.events {
//            self.applyMembershipEvents(events)
//        }
    }
    
    static func == (lhs: RoomModel, rhs: RoomModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Profile refresh from ContactManager
    func applyUpdatedContacts(for updatedIds: Set<String>) {
        assertMain()

        var didChange = false

        for userId in updatedIds {
            let formattedUserId = userId.formattedMatrixUserId
            guard var snapshot = memberMap[formattedUserId] else { continue }
            // pull the canonical updated contact
            if let updatedContact = ContactManager.shared.contact(for: formattedUserId) {
                snapshot.contact = updatedContact
                memberMap[formattedUserId] = snapshot
                didChange = true
            }
        }

        if didChange {
            // this repopulates joinedMembers / invitedMembers / leftMembers / bannedMembers
            //rebuildMemberBucketsFromMap()

            // in case last message was from someone whose name just changed
            updateLastSenderName()

            // admins list might depend on contacts you just refreshed
            if isGroup {
                admins = getAdmins()
            }
        }
    }
}

extension RoomModel {
    /// Apply lightweight summary changes coming from RoomSummaryObject
    /// (keeps existing Combine observers & hydration state intact)
    func applySummary(
        name: String?,
        currentUserId: String?,
        avatarUrl: String?,
        lastMessage: String?,
        lastMessageType: String?,
        lastSenderName: String?,
        unreadCount: Int,
        participantsCount: Int,
        lastServerTimestamp: Int64?,
        joinedMemberIds: [String],
        invitedMemberIds: [String],
        leftMemberIds: [String],
        bannedMemberIds: [String]
    ) {
        assertMain()

        setIfChanged(\.currentUserId, currentUserId)
        setIfChanged(\.name, name)
        setIfChanged(\.avatarUrl, avatarUrl)
        setIfChanged(\.lastMessage, lastMessage)
        setIfChanged(\.lastMessageType, lastMessageType ?? self.lastMessageType)
        setIfChanged(\.lastSenderName, lastSenderName)
        setIfChanged(\.unreadCount, unreadCount)
        setIfChanged(\.lastServerTimestamp, lastServerTimestamp)

        // IDs → recompute derived buckets (keeps snapshot path light)
        if self.joinedMemberIds != joinedMemberIds
            || self.invitedMemberIds != invitedMemberIds
            || self.leftMemberIds != leftMemberIds
            || self.bannedMemberIds != bannedMemberIds {

            self.joinedMemberIds = joinedMemberIds
            self.invitedMemberIds = invitedMemberIds
            self.leftMemberIds = leftMemberIds
            self.bannedMemberIds = bannedMemberIds

            // Refresh SoT + derived participants without marking hydrated
//            seedMemberMapFromCachedMembers(
//                joined: joinedMemberIds,
//                invited: invitedMemberIds,
//                left: leftMemberIds,
//                banned: bannedMemberIds,
//                baselineTS: self.serverTimestamp ?? self.createdAt
//            )
        }

        // Participant count & group flags
        if self.participantsCount != participantsCount {
            self.participantsCount = participantsCount
            self.isGroup = participantsCount > 2
        }
    }
}
