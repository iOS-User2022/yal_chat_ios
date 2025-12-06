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

//    private func setupObserversIfNeeded() {
//        guard !observersAttached else { return }
//        observersAttached = true
//        setupObservers()
//    }

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
    @Published var lastSender: String? = ""
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
    @Published var adminIds: [String] = []
    @Published var isLeft: Bool = false
    @Published var joinedMemberIds: [String] = []
    @Published var invitedMemberIds: [String] = []
    @Published var leftMemberIds: [String] = []
    @Published var bannedMemberIds: [String] = []
    @Published var participants: [ContactModel] = []
    @Published var activeParticipants: [ContactModel] = []
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
        serverTimestamp: Int64?,
        lastServerTimestamp: Int64?,
        joinedMemberIds: [String] = [],
        invitedMemberIds: [String] = [],
        leftMemberIds: [String] = [],
        bannedMemberIds: [String] = [],
        adminIds: [String] = []
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
        self.serverTimestamp = serverTimestamp
        self.lastServerTimestamp = lastServerTimestamp

        // Meta
        self.creator = ""
        self.createdAt = nil

        self.joinedMemberIds = joinedMemberIds
        self.invitedMemberIds = invitedMemberIds
        self.leftMemberIds = leftMemberIds
        self.bannedMemberIds = bannedMemberIds
        self.adminIds = adminIds
        
        self.participants = []
        self.participantsCount = participantsCount
        self.activeParticipants = joinedMembers + invitedMembers
        self.isGroup = participantsCount > 2
        self.admins = []
        
        if let currentUserId {
            self.isLeft = leftMemberIds.contains(currentUserId) || bannedMemberIds.contains(currentUserId)
        }
        // Matrix state placeholders
        self.state = nil
        self.timeline = nil
        self.summary = nil
        self.unreadNotifications = nil

        // Snapshot stays LIGHT: no observers, no memberMap seeding
        self.randomeProfileColor = randomBackgroundColor()
        self.isHydrated = false
//        setupObserversIfNeeded()
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
        participantsCount: Int = 0,
        joinedMembers: [String] = [],
        invitedMembers: [String] = [],
        leftMembers: [String] = [],
        bannedMembers: [String] = [],
        serverTimestamp: Int64?,
        lastServerTimestamp: Int64?,
        adminIds: [String] = [],
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
        if let currentUserId {
            self.isLeft = isLeft || leftMembers.contains(currentUserId) || bannedMembers.contains(currentUserId)
        }
        
        // Admins
        self.admins = admins
        self.adminIds = adminIds
        
        // Matrix state
        self.state = StateEvents(events: state)
        self.timeline = nil
        self.summary = nil
        self.unreadNotifications = nil
        
        // Observers + derived
        //setupObserversIfNeeded()
        self.isHydrated = true
    }
        
    // MARK: - Central update logic for members
//    private func updateMembers(joined: [ContactModel], invited: [ContactModel], left: [ContactModel]) {
//        let participants = joined + invited + left
//        if participants.isEmpty {
//            return
//        }
//        self.participants = participants
//        self.participantsCount = self.participants.count
//        self.isGroup = self.participantsCount > 2
//        
//        // opponent logic
//        if !isGroup, let currentUserId = self.currentUser?.userId {
//            self.opponent = self.participants.first(where: { $0.userId != currentUserId })
//        } else {
//            self.opponent = nil
//        }
//        
//        // room name logic
//        if isGroup {
//            let createRoomEvent = self.state?.events?.first(where: { $0.type == "m.room.name" })
//            if self.name.isEmpty {
//                self.name = createRoomEvent?.content?.name ?? "Group"
//            } else if let newName = createRoomEvent?.content?.name {
//                self.name = newName
//            }
//            
//            if let avatarEvent = self.state?.events?.first(where: { $0.type == "m.room.avatar" }),
//                let avatarUrlString = avatarEvent.content?.url as? String {
//                self.avatarUrl = avatarUrlString
//            }
//        } else if let opponent = self.opponent {
//            if let fullName = opponent.fullName, !fullName.isEmpty {
//                self.name = fullName
//            } else {
//                self.name = opponent.phoneNumber
//            }
//            self.avatarUrl = opponent.avatarURL
//        } else {
//            self.name = "Chat"
//        }
//    }
    
    // MARK: - Combine observers
//    func setupObservers() {
//        Publishers.CombineLatest3($joinedMembers, $invitedMembers, $leftMembers)
//            .sink { [weak self] joined, invited, left in
//                self?.updateMembers(joined: joined, invited: invited, left: left)
//            }
//            .store(in: &cancellables)
//    }
    
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
    static func == (lhs: RoomModel, rhs: RoomModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
        serverTimestamp: Int64?,
        lastServerTimestamp: Int64?,
        joinedMemberIds: [String],
        invitedMemberIds: [String],
        leftMemberIds: [String],
        bannedMemberIds: [String],
        adminMemberIds: [String]
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
        setIfChanged(\.serverTimestamp, serverTimestamp)

        if self.joinedMemberIds != joinedMemberIds
            || self.invitedMemberIds != invitedMemberIds
            || self.leftMemberIds != leftMemberIds
            || self.bannedMemberIds != bannedMemberIds {

            self.joinedMemberIds = joinedMemberIds
            self.invitedMemberIds = invitedMemberIds
            self.leftMemberIds = leftMemberIds
            self.bannedMemberIds = bannedMemberIds
        }

        // Participant count & group flags
        if self.participantsCount != participantsCount {
            self.participantsCount = participantsCount
            self.isGroup = participantsCount > 2
        }
        
        self.activeParticipants = joinedMembers + invitedMembers
        if self.isGroup {
            self.adminIds = adminMemberIds
        }
        
        if let currentUserId = self.currentUserId {
            self.isLeft = leftMemberIds.contains(currentUserId) || bannedMemberIds.contains(currentUserId)
        }
    }
}
