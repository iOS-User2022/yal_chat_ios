//
//  RoomSummaryAdapter.swift
//  YAL
//
//  Created by Vishal Bhadade on 08/10/25.
//


import Foundation

struct RoomSummaryAdapter {

    struct MemberSnapshot {
        let userId: String
        var status: MembershipStatus
        var ts: Int64
    }

    static func make(
        roomId: String,
        stateEvents: [Event],
        timelineEvents: [Event]?,
        currentUserId: String,
        unreadCount: Int = 0
    ) -> RoomSummaryModel {

        // ---- timestamps & last message
        let timeline = (timelineEvents ?? [])
        let newestTs = (timeline.map { $0.originServerTs ?? 0 }.max())
            ?? (stateEvents.map { $0.originServerTs ?? 0 }.max())
        let oldestTs = (timeline.map { $0.originServerTs ?? 0 }.min())
            ?? (stateEvents.map { $0.originServerTs ?? 0 }.min())

        let lastMsg = timeline.last(where: { $0.type == "m.room.message" })
        let lastMessageBody = lastMsg?.content?.body
        let lastSender = lastMsg?.sender

        // ---- creator / createdAt
        let createEv = stateEvents.first(where: { $0.type == "m.room.create" })
        let creator = createEv?.sender ?? ""
        let createdAt = createEv?.originServerTs

        // ---- name / avatar from state first, fallback to heuristics
        let explicitName = stateEvents
            .first(where: { $0.type == "m.room.name" })?
            .content?.name ?? ""

        let explicitAvatar = stateEvents
            .first(where: { $0.type == "m.room.avatar" })?
            .content?.url as String?

        // ---- power levels -> admins (≥ 50)
        let admins: [String] = {
            guard
                let plevel = stateEvents.last(where: { $0.type == "m.room.power_levels" })?.content?.users
            else { return [] }
            return plevel.compactMap { (uid, lv) in lv >= 50 ? uid : nil }
        }()

        // ---- membership SOT (like RoomModel.applyMembershipEvents)
        var memberMap: [String: MemberSnapshot] = [:]
        func upsert(_ uid: String, _ st: MembershipStatus, _ ts: Int64) {
            if let ex = memberMap[uid], ex.ts > ts { return }
            memberMap[uid] = .init(userId: uid, status: st, ts: ts)
        }

        @inline(__always)
        func status(from raw: String) -> MembershipStatus? {
            MembershipStatus(rawValue: raw)
        }

        for e in stateEvents where e.type == "m.room.member" {
            guard let uid = e.stateKey,
                  let raw = e.content?.membership,
                  let st = status(from: raw) else { continue }
            let ts = e.originServerTs ?? 0
            upsert(uid, st, ts)
        }
        if !timeline.isEmpty {
            for e in timeline where e.type == "m.room.member" {
                guard let uid = e.stateKey,
                      let raw = e.content?.membership,
                      let st = status(from: raw) else { continue }
                let ts = e.originServerTs ?? 0
                upsert(uid, st, ts)
            }
        }

        // ---- buckets (newest-first ordering)
        let values = memberMap.values.sorted { $0.ts > $1.ts }
        let joined  = values.filter { $0.status == .join  }.map(\.userId)
        let invited = values.filter { $0.status == .invite}.map(\.userId)
        let left    = values.filter { $0.status == .leave}.map(\.userId)
        let banned  = values.filter { $0.status == .ban }.map(\.userId)
        
        let participantsCount = (joined + invited + left + banned).count
        let isGroup = participantsCount > 2

        // ---- 1:1 opponent + fallback name rules (match your RoomModel logic)
        let opponentUserId: String? = {
            guard !isGroup else { return nil }
            return joined.first(where: { $0 != currentUserId }) ?? invited.first(where: { $0 != currentUserId })
        }()

        let computedName: String = {
            if isGroup {
                return explicitName.isEmpty ? "Group" : explicitName
            } else {
                if let opp = opponentUserId {
                    // try state member displayname
                    if let nameEvent = stateEvents.first(where: { $0.type == "m.room.member" && $0.stateKey == opp }),
                       let dn = nameEvent.content?.name, !dn.isEmpty {
                        return dn
                    }
                    return opp // fallback to userId; UI may resolve later via contacts
                }
                return explicitName.isEmpty ? "Chat" : explicitName
            }
        }()

        let isLeft: Bool = {
            if let snap = memberMap[currentUserId] {
                return snap.status == .leave || snap.status == .ban
            }
            return false
        }()

        // ---- avatar (in 1:1, prefer opponent avatar if present in state)
        let computedAvatar: String? = {
            if isGroup { return explicitAvatar }
            if let opp = opponentUserId {
                if let mem = (stateEvents.first { $0.type == "m.room.member" && $0.stateKey == opp }),
                   let av = mem.content?.avatarUrl, !av.isEmpty {
                    return av
                }
            }
            return explicitAvatar
        }()
        
        return RoomSummaryModel(
            id: roomId,
            currentUserId: currentUserId,
            name: computedName,
            avatarUrl: computedAvatar,
            lastMessage: lastMessageBody,
            lastMessageType: nil,
            lastSender: lastSender,
            lastSenderName: nil,
            unreadCount: unreadCount,
            participantsCount: participantsCount,
            serverTimestamp: newestTs,
            lastServerTimestamp: oldestTs,
            creator: creator,
            createdAt: createdAt,
            isLeft: isLeft,
            isGroup: isGroup,
            adminIds: admins,
            admins: [],
            joinedUserIds: joined,
            invitedUserIds: invited,
            leftUserIds: left,
            bannedUserIds: banned,
            opponentUserId: opponentUserId,
            joinedMembers: [],
            invitedMembers: [],
            leftMembers: [],
            bannedMembers: [],
            participants: []
        )
    }
    
    static func update(
        _ prev: RoomSummaryModel,
        stateEvents: [Event]?,          // new state delta (optional)
        timelineEvents: [Event]?,       // new timeline delta (optional)
        currentUserId: String?,         // needed for isLeft/opponent/name/1:1 avatar
        unreadCount: Int? = nil         // allow unread override
    ) -> RoomSummaryModel {
        let state = stateEvents ?? []
        let timeline = timelineEvents ?? []
        
        // --- Start from previous summary
        var name               = prev.name
        var avatarUrl          = prev.avatarUrl
        var lastMessage        = prev.lastMessage
        var lastSender         = prev.lastSender
        var serverTs           = prev.serverTimestamp
        var lastServerTs       = prev.lastServerTimestamp
        var creator            = prev.creator
        var createdAt          = prev.createdAt
        var adminIds             = Set(prev.adminIds)
        var joined             = Set(prev.joinedUserIds)
        var invited            = Set(prev.invitedUserIds)
        var left               = Set(prev.leftUserIds)
        var banned             = Set(prev.bannedUserIds)
        var opponentUserId     = prev.opponentUserId
        
        // --- Timestamps roll forward
        if let maxTs = (timeline.map { $0.originServerTs ?? 0 }.max())
            ?? (state.map { $0.originServerTs ?? 0 }.max()) {
            serverTs = max(serverTs ?? 0, maxTs)
        }
        if let minTs = (timeline.map { $0.originServerTs ?? 0 }.min())
            ?? (state.map { $0.originServerTs ?? 0 }.min()) {
            lastServerTs = (lastServerTs == nil) ? minTs : min(lastServerTs!, minTs)
        }
        
        // --- creator / createdAt (prefer earliest available)
        if let create = (state.first { $0.type == "m.room.create" })
            ?? (timeline.first { $0.type == "m.room.create" }) {
            if creator.isEmpty { creator = create.sender ?? creator }
            if createdAt == nil { createdAt = create.originServerTs }
        }
        
        // --- name / avatar (room-scoped)
        if let ev = (state.first { $0.type == "m.room.name" })
            ?? (timeline.first { $0.type == "m.room.name" }),
           let n = ev.content?.name, !n.isEmpty {
            name = n
        }
        if let ev = (state.first { $0.type == "m.room.avatar" })
            ?? (timeline.first { $0.type == "m.room.avatar" }),
           let a = ev.content?.url as String?, !(a).isEmpty {
            avatarUrl = a
        }
        
        // --- last message (timeline)
        if let msg = timeline.last(where: { $0.type == "m.room.message" }) {
            lastMessage = msg.content?.body
            lastSender  = msg.sender
        }
        
        // --- admins from power levels (>= 50)
        if let plevelUsers = ((state.last { $0.type == "m.room.power_levels" })
                              ?? (timeline.last { $0.type == "m.room.power_levels" }))?.content?.users {
            adminIds = Set(plevelUsers.compactMap { $1 >= 50 ? $0 : nil })
        }
        
        // --- Membership SoT (apply deltas)
        func applyMembership(_ events: [Event]) {
            for e in events where e.type == "m.room.member" {
                guard let uid = e.stateKey,
                      let raw = e.content?.membership,
                      let st  = MembershipStatus(rawValue: raw) else { continue }
                // Move user across buckets
                switch st {
                case .join:
                    joined.insert(uid); invited.remove(uid); left.remove(uid); banned.remove(uid)
                case .invite:
                    invited.insert(uid); joined.remove(uid); left.remove(uid); banned.remove(uid)
                case .leave:
                    left.insert(uid); joined.remove(uid); invited.remove(uid); banned.remove(uid)
                case .ban:
                    banned.insert(uid); joined.remove(uid); invited.remove(uid); left.remove(uid)
                case .knock:
                    break
                }
            }
        }
        applyMembership(state)
        applyMembership(timeline)
        
        // --- Counts + isGroup
        let participantsCount = Set(joined).union(invited).union(left).union(banned).count
        let isGroup = participantsCount > 2
        
        // --- 1:1 opponent + name/avatar heuristics
        if !isGroup, let me = currentUserId {
            // choose opponent if needed
            if opponentUserId == nil {
                opponentUserId = joined.first(where: { $0 != me })
                ?? invited.first(where: { $0 != me })
            }
            if let opp = opponentUserId {
                // prefer opponent display name if present
                if let mem = (state.first { $0.type == "m.room.member" && $0.stateKey == opp })
                    ?? (timeline.first { $0.type == "m.room.member" && $0.stateKey == opp }),
                   let dn = mem.content?.name, !dn.isEmpty {
                    name = dn
                } else if name.isEmpty || name == "Chat" {
                    name = opp
                }
                // prefer opponent avatar if present
                if let mem = (state.first { $0.type == "m.room.member" && $0.stateKey == opp })
                    ?? (timeline.first { $0.type == "m.room.member" && $0.stateKey == opp }),
                   let av = mem.content?.avatarUrl, !av.isEmpty {
                    avatarUrl = av
                }
            } else if name.isEmpty {
                name = "Chat"
            }
        } else if isGroup, name.isEmpty {
            name = "Group"
        }
        
        // --- Is current user left/banned?
        let isLeft: Bool = {
            guard let me = currentUserId else { return prev.isLeft }
            return left.contains(me) || banned.contains(me)
        }()
        
        return RoomSummaryModel(
            id: prev.id,
            currentUserId: currentUserId ?? "",
            name: name,
            avatarUrl: avatarUrl,
            lastMessage: lastMessage,
            lastMessageType: nil,
            lastSender: lastSender,
            lastSenderName: nil,
            unreadCount: unreadCount ?? prev.unreadCount,
            participantsCount: participantsCount,
            serverTimestamp: serverTs,
            lastServerTimestamp: lastServerTs,
            creator: creator,
            createdAt: createdAt,
            isLeft: isLeft,
            isGroup: isGroup,
            adminIds: Array(adminIds),
            admins: [],
            joinedUserIds: Array(joined),
            invitedUserIds: Array(invited),
            leftUserIds: Array(left),
            bannedUserIds: Array(banned),
            opponentUserId: opponentUserId,
            joinedMembers: [],
            invitedMembers: [],
            leftMembers: [],
            bannedMembers: [],
            participants: []
        )
    }
}
