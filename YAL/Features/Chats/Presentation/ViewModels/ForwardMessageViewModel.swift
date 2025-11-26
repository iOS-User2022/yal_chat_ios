//
//  ForwardMessageViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/06/25.
//


import SwiftUI
import Combine

enum ForwardTarget: Hashable {
    case room(RoomModel)
    case contact(ContactLite)

    var id: String {
        switch self {
        case .room(let room): return room.id
        case .contact(let contact): return contact.userId ?? ""
        }
    }

    static func == (lhs: ForwardTarget, rhs: ForwardTarget) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class ForwardMessageViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedTargets: [ForwardTarget] = []
    @Published var recentChats: [RoomModel] = []
    @Published var frequentChats: [RoomModel] = []
    @Published var yalContacts: [ContactLite] = []
    @Published var currentUser: ContactLite?

    private var cancellables = Set<AnyCancellable>()
    
    private let roomService: RoomServiceProtocol
    private let contactSyncCoordinator: ContactSyncCoordinator
    
    init(
        roomService: RoomServiceProtocol,
        contactSyncCoordinator: ContactSyncCoordinator
    ) {
        self.roomService = roomService
        self.contactSyncCoordinator = contactSyncCoordinator
        
        if let profileModel = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            self.currentUser = ContactLite(userId: authSession.userId, fullName: profileModel.name, phoneNumber: profileModel.mobile)
        }
        
        // Recent Chats - based on last message timestamp
        Publishers.CombineLatest(roomService.roomsPublisher, $searchText)
            .map { (rooms, search) in
                var filtered = rooms
                if !search.isEmpty {
                    let lower = search.lowercased()
                    filtered = filtered.filter {
                        $0.name.lowercased().contains(lower) ||
                        $0.participants.contains(where: { $0.displayName?.lowercased().contains(lower) == true }) ||
                        $0.participants.contains(where: { $0.phoneNumber.lowercased().contains(lower) == true })
                    }
                }
      
                let filteredRooms = filtered
                    .sorted { (lhs, rhs) in
                        (lhs.serverTimestamp ?? 0) > (rhs.serverTimestamp ?? 0)
                    }
                
                // Sort those filteredRooms alphabetically
                return filteredRooms.sorted { $0.name.lowercased() < $1.name.lowercased() }
            }
            .assign(to: &$recentChats)
        
        // Frequently Contacted - based on message count
        Publishers.CombineLatest(roomService.roomsPublisher, roomService.messageCountsPublisher)
            .combineLatest($searchText)
            .map { (roomsAndCounts, search) in
                let (rooms, counts) = roomsAndCounts
                var filtered = rooms.filter { !$0.isGroup }
                if !search.isEmpty {
                    let lower = search.lowercased()
                    filtered = filtered.filter {
                        $0.name.lowercased().contains(lower) ||
                        $0.participants.contains(where: { $0.displayName?.lowercased().contains(lower) == true }) ||
                        $0.participants.contains(where: { $0.phoneNumber.lowercased().contains(lower) == true })
                    }
                }
                // 1. Sort by count desc, then by name for equal counts
                let top10 = filtered
                    .sorted {
                        let c1 = counts[$0.id] ?? 0
                        let c2 = counts[$1.id] ?? 0
                        if c1 == c2 {
                            return $0.name.lowercased() < $1.name.lowercased()
                        }
                        return c1 > c2
                    }
                    .prefix(4)
                
                // 2. Sort top 10 alphabetically by name
                return top10.sorted { $0.name.lowercased() < $1.name.lowercased() }
            }
            .assign(to: &$frequentChats)
        
        // YAL Contacts - just filter/sort your contacts as needed
        contactSyncCoordinator.enrichedContactsPublisher
            .combineLatest($searchText)
            .map { contacts, search in
                // Filter out contacts that do not have a valid userId
                let validContacts = contacts.filter { $0.userId != nil && !$0.userId!.isEmpty }
                let filteredContacts: [ContactLite]
                if search.isEmpty {
                    filteredContacts = validContacts
                } else {
                    let lower = search.lowercased()
                    filteredContacts = validContacts.filter {
                        $0.fullName?.lowercased().contains(lower) ?? false ||
                        $0.phoneNumber.lowercased().contains(lower)
                    }
                }
                // Sort alphabetically
                return filteredContacts.sorted { $0.fullName?.lowercased() ?? "" < $1.fullName?.lowercased() ?? "" }
            }
            .assign(to: &$yalContacts)
    }
    
    func toggleSelection(target: ForwardTarget) {
        if let index = selectedTargets.firstIndex(of: target) {
            selectedTargets.remove(at: index)
        } else {
            if selectedTargets.count == 5 {
                return
            }
            selectedTargets.append(target)
        }
    }
    
    func forwardMessage(message: ChatMessageModel, completion: @escaping () -> Void) {
        let currentUserId = currentUser?.userId
        let group = DispatchGroup()
        LoaderManager.shared.show()
        
        if (message.mediaUrl != nil) || (message.mediaUrl != "") {
            
            getMessageWithUpdatedMediaInfo(message: message) { [self] updatedMessage in
                
                for target in selectedTargets {
                    switch target {
                    case .room(let room):
                        group.enter()
                        roomService.sendMessage(message: updatedMessage, roomId: room.id)
                            .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                            .store(in: &cancellables)
                        
                    case .contact(let contact):
                        // If a room with this contact already exists, use it
                        if let userId = currentUserId, let receiverUserId = contact.userId {
                            if let room = findExistingDirectRoom(with: receiverUserId) {
                                group.enter()
                                roomService.sendMessage(message: updatedMessage, roomId: room.id)
                                    .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                    .store(in: &cancellables)
                            } else {
                                group.enter()
                                // Create new 1-on-1 room, then send
                                roomService.createAndFetchRoomModel(currentUser: userId, invitees: [receiverUserId], roomName: contact.fullName, roomDisplayImageUrl: contact.avatarURL ?? "")
                                    .compactMap { $0 }
                                    .flatMap { room in
                                        self.roomService.sendMessage(message: updatedMessage, roomId: room.id)
                                    }
                                    .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                    .store(in: &cancellables)
                            }
                        }
                    }
                }
            }
            
        } else {
            
            for target in selectedTargets {
                switch target {
                case .room(let room):
                    group.enter()
                    roomService.sendMessage(message: message, roomId: room.id)
                        .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                        .store(in: &cancellables)
                    
                case .contact(let contact):
                    // If a room with this contact already exists, use it
                    if let userId = currentUserId, let receiverUserId = contact.userId {
                        if let room = findExistingDirectRoom(with: receiverUserId) {
                            group.enter()
                            roomService.sendMessage(message: message, roomId: room.id)
                                .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                .store(in: &cancellables)
                        } else {
                            group.enter()
                            // Create new 1-on-1 room, then send
                            roomService.createAndFetchRoomModel(currentUser: userId, invitees: [receiverUserId], roomName: contact.fullName, roomDisplayImageUrl: contact.avatarURL ?? "")
                                .compactMap { $0 }
                                .flatMap { room in
                                    self.roomService.sendMessage(message: message, roomId: room.id)
                                }
                                .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                .store(in: &cancellables)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion()
            LoaderManager.shared.hide()
        }
    }
    
    func forwardMultipleMessage(messages: [ChatMessageModel], completion: @escaping () -> Void) {
        let currentUserId = currentUser?.userId
        let group = DispatchGroup()
        LoaderManager.shared.show()
        
        for target in selectedTargets {
            switch target {
            case .room(let room):
                messages.forEach { message in
                    group.enter()
                    
                    if message.mediaUrl != nil {
                        getMessageWithUpdatedMediaInfo(message: message) { [self] updatedMessage in
                            roomService.sendMessage(message: updatedMessage, roomId: room.id)
                                .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                .store(in: &cancellables)
                        }
                    } else {
                        roomService.sendMessage(message: message, roomId: room.id)
                            .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                            .store(in: &cancellables)
                    }
                }
                
            case .contact(let contact):
                // If a room with this contact already exists, use it
                if let userId = currentUserId, let receiverUserId = contact.userId {
                    if let room = findExistingDirectRoom(with: receiverUserId) {
                        messages.forEach { message in
                            group.enter()
                            if message.mediaUrl != nil {
                                getMessageWithUpdatedMediaInfo(message: message) { [self] updatedMessage in
                                    
                                    roomService.sendMessage(message: updatedMessage, roomId: room.id)
                                        .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                        .store(in: &cancellables)
                                }
                            } else {
                                roomService.sendMessage(message: message, roomId: room.id)
                                    .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                    .store(in: &cancellables)
                            }
                        }
                    } else {
                        messages.forEach { message in
                            group.enter()
                            // Create new 1-on-1 room, then send
                            roomService.createAndFetchRoomModel(currentUser: userId, invitees: [receiverUserId], roomName: contact.fullName, roomDisplayImageUrl: contact.avatarURL ?? "")
                                .compactMap { $0 }
                                .flatMap { room in
                                    self.roomService.sendMessage(message: message, roomId: room.id)
                                }
                                .sink(receiveCompletion: { _ in group.leave() }, receiveValue: { _ in })
                                .store(in: &cancellables)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion()
            LoaderManager.shared.hide()
        }
    }
    
    func getMessageWithUpdatedMediaInfo(message: ChatMessageModel, completion: @escaping (ChatMessageModel) -> Void) {
        // Check if the message has a media URL
        guard let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty else {
            // If no media URL, simply return the original message
            completion(message)
            return
        }
        
        // Fetch media dimensions (width & height)
        getMediaDimensions(mediaType: message.msgType, localURL: "") { width, height in
            let mediaInfo = MediaInfo(
                thumbnailUrl: "",
                thumbnailInfo: nil, // Can be computed if needed
                w: width,
                h: height,
                duration: Int(message.mediaInfo?.duration ?? 0),
                size: Int(message.mediaInfo?.size ?? 0),
                mimetype: "image/jpeg" // This could be dynamic based on message type
            )
            
            var tempmsg = message
            tempmsg.mediaInfo = mediaInfo
            tempmsg.downloadProgress = 0.0
            tempmsg.downloadState = .notStarted
            
            // Return the updated message
            completion(tempmsg)
        }
    }
    
    func findExistingDirectRoom(with userId: String) -> RoomModel? {
        // 1. Combine all rooms and deduplicate by room.id
        let allRooms = (recentChats + frequentChats)
        let uniqueRooms = Dictionary(grouping: allRooms, by: { $0.id })
            .compactMap { $0.value.first } // Pick first occurrence for each unique id
        
        // 2. Filter to direct rooms with both users
        let directRooms = uniqueRooms.filter { room in
            !room.isGroup &&
            room.participants.count == 2 &&
            room.participants.contains(where: { $0.userId == userId })
        }
        // 3. Return the most recently active, or just the first one found
        return directRooms.sorted { ($0.serverTimestamp ?? 0) > ($1.serverTimestamp ?? 0) }.first
    }
}
