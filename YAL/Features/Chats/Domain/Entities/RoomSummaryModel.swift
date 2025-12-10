//
//  RoomSummaryModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 08/10/25.
//


import Foundation

struct RoomSummaryModel: Equatable, Sendable, Identifiable {
    // Identity
    let id: String
    var currentUserId: String

    // Display
    var name: String
    var avatarUrl: String?
    var lastMessage: String?
    var lastMessageType: String?
    var lastSender: String?
    var lastSenderName: String?
    var unreadCount: Int
    var participantsCount: Int
    var serverTimestamp: Int64?
    var lastServerTimestamp: Int64?

    // Meta
    var creator: String
    var createdAt: Int64?
    var isLeft: Bool
    var isGroup: Bool

    // Admins (userIds)
    var admins: [ContactLite] = []
    var adminIds: [String]

    // Membership IDs
    var joinedUserIds: [String]
    var invitedUserIds: [String]
    var leftUserIds: [String]
    var bannedUserIds: [String]

    var opponentUserId: String?

    var joinedMembers: [ContactLite] = []
    var invitedMembers: [ContactLite] = []
    var leftMembers: [ContactLite] = []
    var bannedMembers: [ContactLite] = []
    var participants: [ContactLite] = []

    var activeParticipantIds: [String] = []
    var activeParticipants: [ContactLite] = []
    
    private struct MemberSnapshot {
        var contact: ContactLite
        var status: MembershipStatus
        var ts: Int64
    }

    private var memberMap: [String: MemberSnapshot] = [:]

    @inline(__always)
    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    
    // Works whether originServerTs is Int? or Int64?
    @inline(__always) private func ts64(_ x: Int?) -> Int64 { x.map(Int64.init) ?? nowMs() }
    @inline(__always) private func ts64(_ x: Int64?) -> Int64 { x ?? nowMs() }
    
    init(
        id: String,
        currentUserId: String,
        name: String,
        avatarUrl: String?,
        lastMessage: String?,
        lastMessageType: String?,
        lastSender: String?,
        lastSenderName: String?,
        unreadCount: Int,
        participantsCount: Int,
        serverTimestamp: Int64?,
        lastServerTimestamp: Int64?,
        creator: String,
        createdAt: Int64?,
        isLeft: Bool,
        isGroup: Bool,
        adminIds: [String],
        admins: [ContactLite],
        joinedUserIds: [String],
        invitedUserIds: [String],
        leftUserIds: [String],
        bannedUserIds: [String],
        opponentUserId: String?,
        joinedMembers: [ContactLite],
        invitedMembers: [ContactLite],
        leftMembers: [ContactLite],
        bannedMembers: [ContactLite],
        participants: [ContactLite]
    ) {
        self.id = id
        self.currentUserId = currentUserId
        self.name = name
        self.avatarUrl = avatarUrl
        self.lastMessage = lastMessage
        self.lastMessageType = lastMessageType
        self.lastSender = lastSender
        self.lastSenderName = lastSenderName
        self.unreadCount = unreadCount
        self.participantsCount = participantsCount
        self.serverTimestamp = serverTimestamp
        self.lastServerTimestamp = lastServerTimestamp
        self.creator = creator
        self.createdAt = createdAt
        self.isLeft = isLeft || bannedUserIds.contains(currentUserId) || leftUserIds.contains(currentUserId)
        self.isGroup = isGroup
        self.adminIds = adminIds
        self.joinedUserIds = joinedUserIds
        self.invitedUserIds = invitedUserIds
        self.leftUserIds = leftUserIds
        self.bannedUserIds = bannedUserIds
        self.opponentUserId = opponentUserId
        self.joinedMembers = joinedMembers
        self.invitedMembers = invitedMembers
        self.leftMembers = leftMembers
        self.bannedMembers = bannedMembers
        self.participants = participants
        self.activeParticipants = joinedMembers + invitedMembers
        // SoT stays private and starts empty
        self.memberMap = [:]
    }
    
    mutating func hydrateContacts(resolveMany: ([String]) -> [String: ContactLite]) {
        // Gather unique IDs and resolve to contacts in one shot
        let allIds = Array(Set(joinedUserIds + invitedUserIds + leftUserIds + bannedUserIds))
        let resolved = resolveMany(allIds) // [userId : ContactLite]

        // Precedence (lowest → highest) so higher wins when we bump ts later
        // ban < leave < invite < join
        var final: [String: MembershipStatus] = [:]
        for u in bannedUserIds  { final[u.formattedMatrixUserId]  = .ban }
        for u in leftUserIds    { final[u.formattedMatrixUserId]  = .leave }
        for u in invitedUserIds { final[u.formattedMatrixUserId]  = .invite }
        for u in joinedUserIds  { final[u.formattedMatrixUserId]  = .join }

        // Monotonic ts to enforce total order across precedence groups
        var ts = (serverTimestamp ?? lastServerTimestamp ?? createdAt ?? nowMs()) * 1000

        // Insert by precedence, bumping ts so later precedence overwrites earlier
        func insert(_ ids: [String], as status: MembershipStatus) {
            for uid in Array(Set(ids.map { $0.formattedMatrixUserId })) {
                ts &+= 1
                upsertMember(userId: uid, status: status, ts: ts, resolved: resolved[uid])
            }
        }

        insert(bannedUserIds,  as: .ban)
        insert(leftUserIds,    as: .leave)
        insert(invitedUserIds, as: .invite)
        insert(joinedUserIds,  as: .join)

        // Build all derived values from SoT
        rebuildFromMemberMap()
    }
    
    @inline(__always)
    private mutating func upsertMember(
        userId rawId: String,
        status: MembershipStatus,
        ts: Int64,
        resolved: ContactLite? = nil
    ) {
        let uid = rawId.formattedMatrixUserId
        if let cur = memberMap[uid], cur.ts >= ts { return }

        let c: ContactLite
        if let r = resolved {
            c = r
        } else if let fromCM = ContactManager.shared.contact(for: uid) {
            c = fromCM
        } else {
            c = ContactLite(userId: uid, fullName: "", phoneNumber: "")
        }

        memberMap[uid] = MemberSnapshot(contact: c, status: status, ts: ts)
    }

    // Derive buckets/participants, lastSenderName, opponentUserId, isGroup, admins, etc., from memberMap.
    private mutating func rebuildFromMemberMap() {
        // split by status (newest first)
        let values = memberMap.values
        let joined  = values.filter { $0.status == .join  }.sorted { $0.ts > $1.ts }
        let invited = values.filter { $0.status == .invite }.sorted { $0.ts > $1.ts }
        let left    = values.filter { $0.status == .leave  }.sorted { $0.ts > $1.ts }
        let banned  = values.filter { $0.status == .ban    }.sorted { $0.ts > $1.ts }
        
        let isMemberLeft: Bool = {
            if let snap = memberMap[currentUserId] {
                return snap.status == .leave || snap.status == .ban
            }
            return false
        }()
        
        // write hydrated ContactLite buckets
        joinedMembers  = joined.map  { $0.contact }
        invitedMembers = invited.map { $0.contact }
        leftMembers    = left.map    { $0.contact }
        bannedMembers  = banned.map  { $0.contact }

        // write ID buckets to keep fields in sync (no dups)
        joinedUserIds  = joined.map  { $0.contact.userId ?? "" }
        invitedUserIds = invited.map { $0.contact.userId ?? "" }
        leftUserIds    = left.map    { $0.contact.userId ?? "" }
        bannedUserIds  = banned.map  { $0.contact.userId ?? "" }

        // participants & derived
        participants = joinedMembers + invitedMembers + leftMembers + bannedMembers
        activeParticipants = joinedMembers + invitedMembers
        participantsCount = participants.count
        isGroup = participantsCount > 2

        // opponent (DM)
        if !isGroup {
            opponentUserId = participants.first { $0.userId != currentUserId }?.userId
        } else {
            admins = participants.filter { cm in
                guard let uid = cm.userId else { return false }
                return adminIds.contains(uid)
            }
            opponentUserId = nil
        }
        
        isLeft = isMemberLeft
        
        // friendly lastSenderName
        if let ls = lastSender, !ls.isEmpty,
           let p = participants.first(where: { $0.userId == ls }) {
            if let fn = p.fullName, !fn.isEmpty      { lastSenderName = fn }
            else if let dn = p.displayName, !dn.isEmpty { lastSenderName = dn }
            else                                      { lastSenderName = p.phoneNumber }
        }

        // room name / avatar for DMs if empty
        if !isGroup, let oppId = opponentUserId,
           let opp = participants.first(where: { $0.userId == oppId }) {
            if let fullName = opp.fullName, !fullName.isEmpty { name = fullName }
            else { name = opp.phoneNumber }
            
            if (avatarUrl ?? "").isEmpty { avatarUrl = opp.avatarURL }
        }
        
        
    }
    
    mutating func syncMembersFromIDs(
        joined: [String],
        invited: [String],
        left: [String],
        banned: [String],
        baselineTS: Int64? = nil
    ) {
        var ts = (serverTimestamp ?? lastServerTimestamp ?? baselineTS ?? createdAt ?? nowMs()) * 1000

        func insert(_ ids: [String], as status: MembershipStatus) {
            for uid in Array(Set(ids.map { $0.formattedMatrixUserId })) {
                upsertMember(userId: uid, status: status, ts: ts, resolved: nil)
            }
        }

        insert(banned,  as: .ban)
        insert(left,    as: .leave)
        insert(invited, as: .invite)
        insert(joined,  as: .join)

        rebuildFromMemberMap()
    }
    
    mutating func applyMembershipEvents(_ events: [Event]) {
        var seq: Int64 = 0
        for e in events where e.type == EventType.roomMember.rawValue {
            guard let rawUid = e.stateKey,
                  let raw = e.content?.membership,
                  let st  = MembershipStatus(rawValue: raw) else { continue }

            let uid = rawUid.formattedMatrixUserId
            let base: Int64 = ts64(e.originServerTs)
            seq &+= 1
            let ts = base * 1000 &+ seq
            upsertMember(userId: uid, status: st, ts: ts, resolved: nil)
        }
        rebuildFromMemberMap()
    }
    
    // MARK: Apply to live RoomModel (MAIN only)
    func applyFull(to room: RoomModel) {
        room.applySummary(
            name: name,
            currentUserId: currentUserId,
            avatarUrl: avatarUrl,
            lastMessage: lastMessage,
            lastMessageType: lastMessageType,
            lastSenderName: lastSenderName,
            unreadCount: unreadCount,
            participantsCount: participantsCount,
            serverTimestamp: serverTimestamp,
            lastServerTimestamp: lastServerTimestamp,
            joinedMemberIds: joinedUserIds,
            invitedMemberIds: invitedUserIds,
            leftMemberIds: leftUserIds,
            bannedMemberIds: bannedUserIds,
            adminMemberIds: adminIds
        )

        // Map ContactLite → ContactModel and assign
        let joinedCM  = joinedMembers.map(materializeContact)
        let invitedCM = invitedMembers.map(materializeContact)
        let leftCM    = leftMembers.map(materializeContact)
        let bannedCM  = bannedMembers.map(materializeContact)
        let allCM     = joinedCM + invitedCM + leftCM + bannedCM
        let active    = joinedCM + invitedCM
        
        room.joinedMembers = joinedCM
        room.invitedMembers = invitedCM
        room.leftMembers = leftCM
        room.bannedMembers = bannedCM
        room.participants = allCM
        room.activeParticipants = active
        room.participantsCount = allCM.count
        room.isGroup = allCM.count > 2

        if room.isGroup {
            room.admins = allCM.filter { cm in
                guard let uid = cm.userId else { return false }
                return adminIds.contains(uid)
            }
            room.opponent = nil
        } else {
            room.admins = []
            room.opponent = allCM.first { $0.userId != currentUserId }
        }

        room.isLeft = leftUserIds.contains(currentUserId) || bannedUserIds.contains(currentUserId)
        room.isHydrated = true
    }
    
    func materializeContact(_ lite: ContactLite) -> ContactModel {
        
        return ContactModel(
            fullName: lite.fullName ?? "",
            phoneNumber: lite.phoneNumber,
            emailAddresses: lite.emailAddresses,
            imageURL: lite.avatarURL,
            userId: lite.userId ?? "",
            displayName: lite.displayName,
            about: lite.about,
            dob: lite.dob,
            gender: lite.gender,
            profession: lite.profession
        )
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension RoomSummaryModel {
    
    static func from(
        roomId: String,
        stateEvents: [Event],
        timelineEvents: [Event]? = nil,
        currentUserId: String,
        unreadCount: Int = 0
    ) -> RoomSummaryModel {
        let state = stateEvents.sorted { ($0.originServerTs ?? 0) > ($1.originServerTs ?? 0) }
        let tl    = (timelineEvents ?? []).sorted { ($0.originServerTs ?? 0) > ($1.originServerTs ?? 0) }
        
        let serverTs: Int64 = (tl.first?.originServerTs ?? state.first?.originServerTs ?? 0)
        let lastServerTs: Int64 = serverTs
        
        let createEv = (state + tl).first(where: { $0.type == "m.room.create" })
        let creator   = createEv?.sender ?? ""
        let createdAt = Int64(createEv?.originServerTs ?? 0)
        
        let name = (state + tl).first(where: { $0.type == "m.room.name" })?.content?.name ?? ""
        let avatarUrl = (tl + state).first(where: { $0.type == "m.room.avatar" })?.content?.url
        
        let allEvents = state + tl
            
        let buckets = Self.extractMembershipBuckets(from: allEvents)
        let isLeft = buckets.left.contains(currentUserId) || buckets.invited.contains(currentUserId)
        let lastMsgEv = tl.first(where: { $0.type == "m.room.message" })
        let lastMsg    = lastMsgEv?.content?.body
        let lastSender = lastMsgEv?.sender
        let lastType   = lastMsgEv?.content?.msgType
        
        return RoomSummaryModel(
            id: roomId,
            currentUserId: currentUserId,
            name: name,
            avatarUrl: avatarUrl,
            lastMessage: lastMsg,
            lastMessageType: lastType,
            lastSender: lastSender,
            lastSenderName: nil,
            unreadCount: unreadCount,
            participantsCount: 0,            // will be set during hydration
            serverTimestamp: serverTs,
            lastServerTimestamp: lastServerTs,
            creator: creator,
            createdAt: createdAt,
            isLeft: isLeft,
            isGroup: false,                  // will be set during hydration
            adminIds: buckets.admins,
            admins: [],
            joinedUserIds: buckets.joined,
            invitedUserIds: buckets.invited,
            leftUserIds: buckets.left,
            bannedUserIds: buckets.banned,
            opponentUserId: nil,
            joinedMembers: [],
            invitedMembers: [],
            leftMembers: [],
            bannedMembers: [],
            participants: []
        )
    }
    
    // MARK: - Incremental update (state/timeline/unread)
    
    // Lightweight incremental updater; call this whenever new chunks arrive.
    mutating func update(
        stateEvents newState: [Event]?,
        timelineEvents newTimeline: [TimelineEvent]?,
        unreadCount newUnreadCount: Int? = nil,
        rehydrateWith resolver: (([String]) -> [String: ContactLite])? = nil
    ) {
        // State (name/creator/createdAt/admins + membership)
        if let s = newState, !s.isEmpty {
            let ss = s.sorted { ($0.originServerTs ?? 0) > ($1.originServerTs ?? 0) }

            if let createEv = ss.first(where: { $0.type == "m.room.create" }) {
                creator   = createEv.sender ?? creator
                createdAt = createEv.originServerTs ?? createdAt ?? 0
            }
            if let nm = ss.first(where: { $0.type == "m.room.name" })?.content?.name, !nm.isEmpty {
                name = nm
            }
            // admins (unchanged from your code)
            adminIds = Array(Self.extractAdmins(from: ss))

            // Membership changes → SoT
            applyMembershipEvents(ss)
        }

        // Timeline (avatar/last message + membership)
        if let t = newTimeline, !t.isEmpty {
            let tl = t.sorted { ($0.originServerTs ?? 0) > ($1.originServerTs ?? 0) }
            serverTimestamp     = tl.first?.originServerTs ?? serverTimestamp ?? 0
            lastServerTimestamp = tl.last?.originServerTs  ?? lastServerTimestamp ?? 0

            if let url = tl.first(where: { $0.type == "m.room.avatar" })?.content?.url, !url.isEmpty {
                avatarUrl = url
            }
            if let nm = tl.first(where: { $0.type == "m.room.name" })?.content?.name, !nm.isEmpty {
                name = nm
            }
            if let lastMsgEv = tl.first(where: { $0.type == "m.room.message" }) {
                lastMessage     = lastMsgEv.content?.body
                lastSender      = lastMsgEv.sender
                lastMessageType = lastMsgEv.content?.msgType ?? lastMessageType
            }

            // Membership changes → SoT
            applyMembershipEvents(tl.asEvents())
        }

        if let u = newUnreadCount { unreadCount = u }

        // Optional: rehydrate contacts with a resolver snapshot (thread-safe)
        if let resolver {
            let allIds = Array(Set(memberMap.keys))
            let byId = resolver(allIds)
            var touched = false
            for uid in allIds {
                if let fresh = byId[uid], var snap = memberMap[uid] {
                    snap.contact = fresh
                    memberMap[uid] = snap
                    touched = true
                }
            }
            if touched { rebuildFromMemberMap() }
        }
        updateLastSenderName()
        hydrateAvatarIfNeeded()
    }
    
    // MARK: - Presence/profile refresh (like RoomModel.applyUpdatedContacts)
    mutating func applyUpdatedContacts(for updatedIds: Set<String>) {
        guard !updatedIds.isEmpty else { return }
        var touched = false
        for uidRaw in updatedIds {
            let uid = uidRaw.formattedMatrixUserId
            guard var snap = memberMap[uid] else { continue }
            if let fresh = ContactManager.shared.contact(for: uid) {
                snap.contact = fresh
                memberMap[uid] = snap
                touched = true
            }
        }
        if touched { rebuildFromMemberMap() }
    }
    
    // MARK: - Avatar hydration (summary-level)
    /// For DMs: adopt opponent avatar if room avatar is empty; for events, pick the avatar from event content first.
    mutating func hydrateAvatar(for userId: String, event: Event? = nil) {
        if let ev = event,
           let url = ev.content?.avatarUrl,
           !url.isEmpty {
            avatarUrl = url
            return
        }
        hydrateAvatarIfNeeded()
    }
    
    // MARK: - Apply to live RoomModel (already provided)
    // `applyFull(to:)` and `materializeContact(_:)` exist in your struct. Keep them as-is.
    
    // MARK: - Internals
    
    private mutating func rebuildParticipantsFromHydratedBuckets() {
        participants = joinedMembers + invitedMembers + leftMembers + bannedMembers
        activeParticipants = joinedMembers + invitedMembers
        participantsCount = participants.count
        isGroup = participantsCount > 2
        opponentUserId = isGroup ? nil : participants.first(where: { $0.userId != currentUserId })?.userId
    }
    
    private mutating func updateLastSenderName() {
        guard let ls = lastSender, !ls.isEmpty else { return }
        if let p = participants.first(where: { $0.userId == ls }) {
            if let fn = p.fullName, !fn.isEmpty {
                lastSenderName = fn
            } else if let dn = p.displayName, !dn.isEmpty {
                lastSenderName = dn
            } else {
                lastSenderName = p.phoneNumber
            }
        }
    }
    
    private mutating func hydrateAvatarIfNeeded() {
        guard (avatarUrl ?? "").isEmpty else { return }
        // Prefer DM opponent avatar if not a group
        if !isGroup,
           let oppId = opponentUserId,
           let opp = participants.first(where: { $0.userId == oppId }),
           let av = opp.avatarURL, !av.isEmpty {
            avatarUrl = av
        }
    }
    
    // MARK: - Membership extraction
    private static func extractMembershipBuckets(
        from events: [Event]
    ) -> (joined: [String], invited: [String], left: [String], banned: [String], admins: [String]) {

        struct MemberSnapshot {
            let status: MembershipStatus
            let ts: Int64
            let seq: Int
        }

        // Build latest-per-user snapshots
        var memberMap: [String: MemberSnapshot] = [:]
        var seq = 0
        for e in events where e.type == EventType.roomMember.rawValue {
            seq &+= 1
            guard let rawUid = e.stateKey, !rawUid.isEmpty else { continue }
            let uid = rawUid.formattedMatrixUserId
            guard
                let raw = e.content?.membership,
                let status = MembershipStatus(rawValue: raw)
            else { continue }

            let ts = e.originServerTs ?? 0
            if let cur = memberMap[uid] {
                // pick the newer event (or later-seen if same ts)
                if ts > cur.ts || (ts == cur.ts && seq > cur.seq) {
                    memberMap[uid] = MemberSnapshot(status: status, ts: ts, seq: seq)
                }
            } else {
                memberMap[uid] = MemberSnapshot(status: status, ts: ts, seq: seq)
            }
        }

        // Bucket without any sorting
        var joined:  [String] = []
        var invited: [String] = []
        var left:    [String] = []
        var banned:  [String] = []

        for (uid, snap) in memberMap {
            switch snap.status {
            case .join:   joined.append(uid)
            case .invite: invited.append(uid)
            case .leave:  left.append(uid)
            case .ban:    banned.append(uid)
            case .knock:  break
            }
        }

        // Admins via power-levels (or your existing helper)
        let admins = Array(extractAdmins(from: events))

        return (joined, invited, left, banned, admins)
    }
    
    private static func extractAdmins(from events: [Event]) -> Set<String> {
        var best: Event?
        var bestKey: (Int64, Int) = (Int64.min, -1)

        var seq = 0
        for e in events where e.type == "m.room.power_levels" {
            seq &+= 1
            let ts = e.originServerTs ?? 0
            if ts > bestKey.0 || (ts == bestKey.0 && seq > bestKey.1) {
                best = e
                bestKey = (ts, seq)
            }
        }

        if let power = best, let users = power.content?.users {
            let threshold = 50 // match RoomModel.getAdmins() semantics
            let ids = users.compactMap { (uid, level) -> String? in
                level >= threshold ? uid.formattedMatrixUserId : nil
            }
            return Set(ids)
        }

        // Fallback: latest creator (m.room.create)
        if let creator = latestCreator(from: events) {
            return [creator.formattedMatrixUserId]
        }
        return []
    }
    
    private static func latestCreator(from events: [Event]) -> String? {
        var best: Event?
        var bestKey: (Int64, Int) = (Int64.min, -1)

        var seq = 0
        for e in events where e.type == "m.room.create" {
            seq &+= 1
            let ts = e.originServerTs ?? 0
            if ts > bestKey.0 || (ts == bestKey.0 && seq > bestKey.1) {
                best = e
                bestKey = (ts, seq)
            }
        }
        if let e = best {
            return (e.content?.creator ?? e.sender)?.formattedMatrixUserId
        }
        return nil
    }
    
    mutating func applyMembershipChange(userId rawUserId: String, membership: MembershipStatus) {
        let uid = rawUserId.formattedMatrixUserId
        
        // Remove from all buckets
        joinedUserIds.removeAll  { $0 == uid }
        invitedUserIds.removeAll { $0 == uid }
        leftUserIds.removeAll    { $0 == uid }
        bannedUserIds.removeAll  { $0 == uid }
        
        // Add to the target bucket
        switch membership {
        case .join:   joinedUserIds.append(uid)
        case .invite: invitedUserIds.append(uid)
        case .leave:  leftUserIds.append(uid)
        case .ban:    bannedUserIds.append(uid)
        case .knock:  break // ignore in buckets
        }
        
        // Keep admins list tidy if user leaves/gets banned
        if membership == .leave || membership == .ban {
            adminIds.removeAll { $0 == uid }
        }
        
        var ts = (serverTimestamp ?? nowMs()) * 1000
        ts &+= 1
        upsertMember(userId: uid, status: membership, ts: ts, resolved: nil)
        // Rebuild hydrated members and derived fields
        refreshHydratedMembers()
    }
    
    mutating func applyMembershipChange(userId: String, membershipRaw: String) {
        if let m = MembershipStatus(rawValue: membershipRaw) {
            applyMembershipChange(userId: userId, membership: m)
        }
    }
    
    // MARK: - Minimal hydration/derived recompute
    private mutating func refreshHydratedMembers() {
        func resolve(_ id: String) -> ContactLite {
            if let c = ContactManager.shared.contact(for: id) { return c }
            return ContactLite(userId: id, fullName: "", phoneNumber: "")
        }
        
        joinedMembers  = joinedUserIds.map(resolve)
        invitedMembers = invitedUserIds.map(resolve)
        leftMembers    = leftUserIds.map(resolve)
        bannedMembers  = bannedUserIds.map(resolve)
        
        participants = joinedMembers + invitedMembers + leftMembers + bannedMembers
        activeParticipants = joinedMembers + invitedMembers
        participantsCount = participants.count
        isGroup = participantsCount > 2
        
        // DM opponent + friendly name/avatar
        if !isGroup {
            opponentUserId = participants.first(where: { $0.userId != currentUserId })?.userId
            if let oppId = opponentUserId,
               let opp = participants.first(where: { $0.userId == oppId }) {
                
                if name.isEmpty || name == "Chat" {
                    if let dn = opp.displayName, !dn.isEmpty {
                        name = dn
                    } else if let fn = opp.fullName, !fn.isEmpty {
                        name = fn
                    } else {
                        name = opp.phoneNumber
                    }
                }
                if (avatarUrl ?? "").isEmpty {
                    avatarUrl = opp.avatarURL
                }
            }
        } else {
            admins = participants.filter { cm in
                guard let uid = cm.userId else { return false }
                return adminIds.contains(uid)
            }
            opponentUserId = nil
        }
        
        isLeft = leftUserIds.contains(currentUserId) || bannedUserIds.contains(currentUserId)
        
        updateLastSenderName()
    }
}

// RoomSummaryModel ➜ RoomModel materializer
extension RoomSummaryModel {
    // Create or update a full RoomModel from this (already hydrated) summary.
    // Must run on main because RoomModel mutates @Published properties.
    @MainActor
    func materializeRoomModel(existing: RoomModel? = nil) -> RoomModel {
        if let room = existing {
            // Update the existing instance in-place (no re-hydration restart)
            applyFull(to: room)
            return room
        } else {
            // Create a fresh RoomModel (heavy path initializer),
            // then apply the hydrated summary to fill members/admins/etc.
            let rm = RoomModel(
                id: id,
                name: name,
                currentUser: nil,
                creator: creator,
                createdAt: createdAt,
                avatarUrl: avatarUrl,
                lastMessage: lastMessage,
                lastMessageType: lastMessageType ?? "m.text",
                lastSender: lastSender,
                lastSenderName: lastSenderName,
                unreadCount: unreadCount,
                participantsCount: participantsCount,
                joinedMembers: joinedUserIds,
                invitedMembers: invitedUserIds,
                leftMembers: leftUserIds,
                bannedMembers: bannedUserIds,
                serverTimestamp: serverTimestamp,
                lastServerTimestamp: lastServerTimestamp,
                adminIds: adminIds,
                isLeft: isLeft,
                state: nil
            )

            // Apply hydrated contacts + admins/opponent/etc.
            applyFull(to: rm)
            return rm
        }
    }
}
