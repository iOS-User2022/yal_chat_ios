//
//  RoomService.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/06/25.
//


import Foundation
import Combine

final class BackgroundRoomProcessor {
    private let queue: OperationQueue
    private let chatRepository: ChatRepositoryProtocol   // whatever your type is

    init(chatRepository: ChatRepositoryProtocol) {
        self.chatRepository = chatRepository

        let queue = OperationQueue()
        queue.name = "room.processing.queue"
        queue.maxConcurrentOperationCount = 4    // <- important: don’t run 161 at once
        queue.qualityOfService = .utility
        self.queue = queue
    }

    deinit {
        print("⚠️ BackgroundRoomProcessor deinit") // helps detect accidental deallocation
    }

    
    func enqueue(roomId: String, events: [Event]) {
        // capture values now, run later
        queue.addOperation { [chatRepository] in
            //print("Processed room: \(roomId) — events: \(events.count)")
            
            // IMPORTANT: this code must not hop to main
            chatRepository.upsertRoomSummary(
                roomId: roomId,
                stateEvents: events,
                timelineEvents: nil,
                unreadCount: 0
            )
            
            let unsyncedIds = collectUnsyncedUserIds(from: events)
            
            if !unsyncedIds.isEmpty {
                chatRepository.profileSync.enqueue(unsyncedIds)
            }
        }
    }
}

/// move this out if it’s elsewhere
private func collectUnsyncedUserIds(from events: [Event]) -> [String] {
    // your current logic
    return []
}

//private func collectUnsyncedUserIds(from events: [Event]) -> [String] {
//    var seen = Set<String>()
//    var unsynced = [String]()
//    
//    for e in events where e.type == EventType.roomMember.rawValue {
//        guard let uid = e.stateKey, seen.insert(uid).inserted else { continue }
//        if let c = ContactManager.shared.contact(for: uid) {
//            if !c.isSynced { unsynced.append(uid) }
//        } else {
//            unsynced.append(uid)
//        }
//    }
//    return unsynced
//}

final class RoomService: RoomServiceProtocol {
    private let chatRepository: ChatRepositoryProtocol
    private let userRepository: UserRepository
    private var cancellables = Set<AnyCancellable>()
    private let roomProcessor: BackgroundRoomProcessor
    private let stateFetchQueue = DispatchQueue(label: "room.state.fetch.queue", qos: .userInitiated)
    
    var hydrationProgressPublisher: AnyPublisher<(hydrated: Int, total: Int), Never> {
        chatRepository.hydrationProgressPublisher
    }
    
    var messageBackfillProgressPublisher: AnyPublisher<(done: Int, total: Int), Never> {
        chatRepository.messageBackfillProgressPublisher
    }
    
    func setExpectedRoomsIds(_ ids: [String]) {
        chatRepository.setExpectedRoomsIds(ids)
    }
    
    var redactionPublisher: AnyPublisher<String, Never> {
        chatRepository.redactionPublisher
    }
    
    var roomsPublisher: AnyPublisher<[RoomModel], Never> {
        chatRepository.roomsPublisher.eraseToAnyPublisher()
    }
    
    var chatMessagesPublisher: AnyPublisher<[ChatMessageModel], Never> {
        chatRepository.chatMessagesPublisher.eraseToAnyPublisher()
    }
    
    var messagesClearedPublisher: AnyPublisher<String, Never> {
        chatRepository.messagesClearedPublisher.eraseToAnyPublisher()
    }
    
    var ephemeralPublisher: AnyPublisher<ReceiptUpdate, Never> {
        chatRepository.ephemeralPublisher.eraseToAnyPublisher()
    }
    
    var typingPublisher: AnyPublisher<TypingUpdate, Never> {
        chatRepository.typingPublisher.eraseToAnyPublisher()
    }
    
    var inviteResponsePublisher: AnyPublisher<[String], APIError> {
        chatRepository.inviteResponsePublisher.eraseToAnyPublisher()
    }
    
    var messageCountsPublisher: AnyPublisher<[String: Int], Never> {
        chatRepository.messageCountsPublisher.eraseToAnyPublisher()
    }
    
    init(chatRepository: ChatRepositoryProtocol, userRepository: UserRepository) {
        self.chatRepository = chatRepository
        self.userRepository = userRepository
        self.roomProcessor = BackgroundRoomProcessor(chatRepository: chatRepository)
    }
    
    deinit {
        cancellables.removeAll()
        print("RoomService deinit")
    }
    
    func roomsSnapshot() -> [RoomModel] { chatRepository.roomsSnapshot() }
        
    func warmRoomsCacheIfNeeded(shouldWarmCache: Bool) -> AnyPublisher<Void, Never> {
        chatRepository.warmCacheIfNeeded(shouldWarmCache: shouldWarmCache)
    }
    
    func joinRoom(roomId: String) -> AnyPublisher<APIResult<JoinRoomResponse>, APIError> {
        chatRepository.joinRoom(roomId: roomId)
    }
    
    func enableMessageObservation(for roomId: String) {
        chatRepository.enableMessageObservation(for: roomId)
    }
    
    func disableMessageObservation() {
        chatRepository.disableMessageObservation()
    }
    
    func createAndFetchRoomModel(
        currentUser: String,
        invitees: [String],
        roomName: String?,
        roomDisplayImageUrl: String?
    ) -> AnyPublisher<RoomModel?, APIError> {
        chatRepository.createRoom(
            currentUser: currentUser,
            invitees: invitees,
            roomName: roomName,
            roomDisplayImageUrl: roomDisplayImageUrl
        )
        .flatMap { [weak self] result -> AnyPublisher<RoomModel?, APIError> in
            guard let self = self else {
                return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
            
            switch result {
            case .success(let response):
                let roomId = response.roomId
                
                return self.chatRepository.getStateEvents(forRoom: roomId)
                    .flatMap { [weak self] events -> AnyPublisher<RoomModel?, APIError> in
                        guard let self = self else {
                            return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
                        }
                        
                        // All member userIds (deduped)
                        var seen = Set<String>()
                        let memberUserIds: [String] = events
                            .filter { $0.type == EventType.roomMember.rawValue }
                            .compactMap { $0.stateKey }
                            .compactMap { uid in seen.insert(uid).inserted ? uid : nil }
                        
                        // Only fetch for contacts that exist & are NOT synced yet
                        let unsyncedIds: [String] = memberUserIds.compactMap { uid in
                            if let c = ContactManager.shared.contact(for: uid), c.isSynced == false { return uid }
                            return nil
                        }
                        
                        // If nothing to fetch, just build/update room immediately
                        guard !unsyncedIds.isEmpty else {
                            if let (model, isExisting) = self.chatRepository.getRoomSummaryModel(roomId: roomId, events: events) {
                                var roomSummaryModel = model
                                let resolver: ([String]) -> [String: ContactLite] = { ids in
                                    var out: [String: ContactLite] = [:]
                                    out.reserveCapacity(ids.count)
                                    for raw in ids {
                                        let uid = raw.formattedMatrixUserId
                                        out[uid] = ContactManager.shared.contact(for: uid)
                                            ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                    }
                                    return out
                                }

                                roomSummaryModel.update(
                                    stateEvents: events,
                                    timelineEvents: nil,
                                    unreadCount: nil,
                                    rehydrateWith: resolver
                                )
                                return Just((roomSummaryModel, isExisting))
                                    .setFailureType(to: APIError.self)
                                    .receive(on: DispatchQueue.main)
                                    .map { [weak self] summary, isExisting -> RoomModel? in
                                        guard let self = self else { return nil }
                                        self.chatRepository.updateRoom(room: summary, isExisting: isExisting)
                                        let model = self.chatRepository.upsertRoom(from: summary)
                                        return model
                                    }
                                    .eraseToAnyPublisher()
                            } else {
                                return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
                            }
                        }
                        
                        // Fetch profiles for unsynced members, save, then build room
                        return self.userRepository.getUserProfiles(userIds: unsyncedIds)
                            .mapError { $0 }
                            .map { profiles in
                                let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userID, $0) })
                                
                                for uid in unsyncedIds {
                                    guard let p = byId[uid.trimmedMatrixUserId] else { continue }
                                    
                                    if var contact = ContactManager.shared.contact(for: uid) {
                                        contact.userId = uid
                                        contact.displayName = p.name
                                        contact.emailAddresses = p.email.map { [$0] } ?? []
                                        contact.imageURL = p.profilePic
                                        contact.about = p.about
                                        contact.dob = p.dob
                                        contact.gender = p.gender
                                        contact.profession = p.profession
                                        contact.isSynced = true
                                        
                                        DBManager.shared.saveContacts(contacts: [contact])
                                    } else {
                                        let contactLite = ContactLite(
                                            userId: uid,
                                            fullName: "",
                                            phoneNumber: p.phone ?? "",
                                            emailAddresses: p.email.map { [$0] } ?? [],
                                            imageURL: p.mxcProfile,
                                            avatarURL: p.mxcProfile,
                                            displayName: p.name,
                                            about: p.about,
                                            dob: p.dob,
                                            gender: p.gender,
                                            profession: p.profession,
                                            isBlocked: false,
                                            isSynced: false,
                                            isOnline: false,
                                            lastSeen: nil
                                        )
                                        
                                        DBManager.shared.saveContact(contact: contactLite)
                                    }
                                }
                                return events
                            }
                            .receive(on: DispatchQueue.main)
                            .map { [weak self] updatedEvents -> RoomModel? in
                                guard let self = self else { return nil }
                                if let (model, isExisting) = self.chatRepository.getRoomSummaryModel(roomId: roomId, events: updatedEvents) {
                                    var summary = model
                                    let resolver: ([String]) -> [String: ContactLite] = { ids in
                                        var out: [String: ContactLite] = [:]
                                        out.reserveCapacity(ids.count)
                                        for raw in ids {
                                            let uid = raw.formattedMatrixUserId
                                            out[uid] = ContactManager.shared.contact(for: uid)
                                                ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                        }
                                        return out
                                    }

                                    summary.update(
                                        stateEvents: updatedEvents,
                                        timelineEvents: nil,
                                        unreadCount: nil,
                                        rehydrateWith: resolver
                                    )
                                    self.chatRepository.updateRoom(room: summary, isExisting: isExisting)
                                    let model = self.chatRepository.upsertRoom(from: summary)
                                    return model
                                }
                                return nil
                            }
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
                
            case .unsuccess(let error):
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }
    
    func banFromRoom(roomId: String, userId: String, reason: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.banFromRoom(roomId: roomId, userId: userId, reason: reason)
    }

    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.unbanFromRoom(roomId: roomId, userId: userId)
    }
    
    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.muteRoomNotifications(roomId: roomId, duration: duration)
    }

    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.unmuteRoomNotifications(roomId: roomId)
    }
    
    func getMessages(forRoom roomId: String) {
        chatRepository.getMessages(fromRoom: roomId, limit: 10)
    }
    
    func stopMessageSync() {
        chatRepository.stopMessageFetch()
    }
    
    func sendMessage(message: ChatMessageModel) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.sendMessage(message: message)
    }
    
    func sendMessage(message: ChatMessageModel, roomId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.sendMessage(message: message, roomId: roomId)
    }
    
    func sendReadMarker(roomId: String, fullyReadEventId: String?, readEventId: String?, readPrivateEventId: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.sendReadMarker(roomId: roomId, fullyReadEventId: fullyReadEventId, readEventId: readEventId, readPrivateEventId: readPrivateEventId)
    }
    
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError> {
        chatRepository.uploadMedia(fileURL: fileURL, fileName: fileName, mimeType: mimeType, onProgress: onProgress)
    }
    
    func downloadMediaForMessage(mxcUrl: String, fileName: String, onProgress: ((Double) -> Void)?) -> AnyPublisher<APIResult<URL>, APIError> {
        chatRepository.downloadMediaForMessage(mxcUrl: mxcUrl, fileName: fileName, onProgress: onProgress)
    }
    
    // MARK: - Room Fetching & Population
    func loadCacheAndHydrateRooms(includeContacts: Bool = true) -> AnyPublisher<[RoomSummaryModel], Never> {
        chatRepository.loadCachedRooms()
            .flatMap { [weak self] snaps -> AnyPublisher<[RoomSummaryModel], Never> in
                guard let self = self, !snaps.isEmpty else {
                    return Just(snaps).eraseToAnyPublisher()
                }
                let ids = snaps.map(\.id)
                
                return Deferred {
                    Future<[RoomSummaryModel], Never> { promise in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let full = self.chatRepository.fetchFullRoomSummaries(
                                ids: ids,
                                includeContacts: includeContacts
                            )
                            promise(.success(full))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func loadCacheAndHydrateRoomsNow(includeContacts: Bool = true) {
        loadCacheAndHydrateRooms(includeContacts: includeContacts)
            .sink { _ in }
            .store(in: &cancellables)
    }
    
    func fetchAndPopulateRooms(onlyCache: Bool = false) -> AnyPublisher<RoomProgressEvent, APIError> {
        // Always load cache (to populate in-memory rooms), but decide whether to emit events
        let cache = chatRepository.loadCachedRooms()
            .handleEvents(receiveOutput: { [weak self] snaps in
                self?.setExpectedRoomsIds(snaps.map { $0.id })
            })

        if onlyCache {
            return cache
                .map { _ in () }
                .setFailureType(to: APIError.self)
                .flatMap { _ in Empty<RoomProgressEvent, APIError>(completeImmediately: true) }
                .eraseToAnyPublisher()
        }

        let cachePhase = cache
            .map { snaps in
                RoomProgressEvent.succeeded(id: "cache", index: snaps.count, allIds: snaps.map(\.id))
            }
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()

        let networkPhase = chatRepository.getJoinedRooms()
            .flatMap { [weak self] result -> AnyPublisher<RoomProgressEvent, APIError> in
                guard let self else { return Fail(error: .unknown).eraseToAnyPublisher() }
                switch result {
                case .unsuccess(let e):
                    return Fail(error: e).eraseToAnyPublisher()
                case .success(let resp):
                    let ids = resp.joinedRooms ?? []
                    guard !ids.isEmpty else {
                        return Just(RoomProgressEvent.succeeded(id: "none", index: 1, allIds: ids))
                            .setFailureType(to: APIError.self)
                            .eraseToAnyPublisher()
                    }
                    self.setExpectedRoomsIds(ids)
                    return self.processRoomsConcurrently(ids, concurrency: 4, perRoomTimeout: 25)
                }
            }
            .eraseToAnyPublisher()

        return cachePhase
            .append(networkPhase)
            .eraseToAnyPublisher()
    }
    
    private func processRoomsConcurrently(
        _ roomIds: [String],
        concurrency: Int = 4,
        perRoomTimeout seconds: TimeInterval = 25
    ) -> AnyPublisher<RoomProgressEvent, APIError> {
        guard !roomIds.isEmpty else {
            return Empty().eraseToAnyPublisher()
        }
        
        let total = roomIds.count
        print("Total Rooms: \(total)")
        
        return Publishers.Sequence(sequence: Array(roomIds.enumerated()))
            .flatMap(maxPublishers: .max(concurrency)) { (index, roomId) -> AnyPublisher<RoomProgressEvent, APIError> in
                
                let started = Just(RoomProgressEvent.started(id: roomId, index: index + 1, allIds: roomIds))
                    .setFailureType(to: APIError.self)
                
                let fetch = Deferred { [weak self] in
                    self?.chatRepository.getStateEvents(forRoom: roomId)
                    ?? Just<[Event]>([])
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }
                    .subscribe(on: self.stateFetchQueue)
                    .first()
                    .timeout(.seconds(seconds),
                             scheduler: self.stateFetchQueue,
                             customError: { .timeout })
                    .handleEvents(receiveOutput: { [weak self] events in
                        //print("Received \(events.count) events for room \(roomId)")
                        self?.processRoom(id: roomId, events: events)
                    })
                    .map { _ in
                        RoomProgressEvent.succeeded(id: roomId, index: index + 1, allIds: roomIds)
                    }
                    .catch { error in
                        print("Room \(roomId): FAILED with \(error)")
                        return Just(RoomProgressEvent.failed(id: roomId, index: index + 1, allIds: roomIds, error: error))
                            .setFailureType(to: APIError.self)
                    }
                    .eraseToAnyPublisher()
                
                return started.append(fetch).eraseToAnyPublisher()
            }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .eraseToAnyPublisher()
    }
    
    private func fetchAndProcessRoom(roomId: String) -> AnyPublisher<Void, APIError> {
        chatRepository.getStateEvents(forRoom: roomId)
            .first()
            .map { [weak self] events in
                _ = self?.processRoom(id: roomId, events: events)
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.global())
            .catch { _ in Just(()).setFailureType(to: APIError.self) }
            .eraseToAnyPublisher()
    }
    
    private func processRoom(id roomId: String, events: [Event]) {
        //print("Process room: \(roomId) — events: \(events.count)")
        roomProcessor.enqueue(roomId: roomId, events: events)
    }
    
    private func collectUnsyncedUserIds(from events: [Event]) -> [String] {
        var seen = Set<String>()
        var unsynced = [String]()
        
        for e in events where e.type == EventType.roomMember.rawValue {
            guard let uid = e.stateKey, seen.insert(uid).inserted else { continue }
            if let c = ContactManager.shared.contact(for: uid) {
                if !c.isSynced { unsynced.append(uid) }
            } else {
                unsynced.append(uid)
            }
        }
        return unsynced
    }
    
    func restoreSession(accessToken: String) {
        chatRepository.restoreSession(accessToken: accessToken)
    }
    
    func startSync() {
        chatRepository.startSync()
    }
    
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return chatRepository.leaveRoom(roomId: roomId)
    }
    
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return chatRepository.forgetRoom(roomId: roomId)
    }
    
    func joinAndFetchRoomModel(roomId: String) -> AnyPublisher<RoomModel?, APIError> {
        chatRepository.joinRoom(roomId: roomId)
            .flatMap { [weak self] result -> AnyPublisher<RoomModel?, APIError> in
                guard let self = self else {
                    return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }

                switch result {
                case .success:
                    return self.chatRepository.getStateEvents(forRoom: roomId)
                        .flatMap { events -> AnyPublisher<RoomModel?, APIError> in
                            // Collect all member userIds
                            let memberUserIds = events
                                .filter { $0.type == EventType.roomMember.rawValue }
                                .compactMap { $0.stateKey }

                            // Dedupe and keep only those not yet synced
                            var seen = Set<String>()
                            let unsyncedIds: [String] = memberUserIds.compactMap { uid in
                                guard seen.insert(uid).inserted else { return nil }
                                if let c = ContactManager.shared.contact(for: uid), c.isSynced == false {
                                    return uid
                                }
                                return nil
                            }

                            // If nothing to fetch, build/update room immediately
                            if unsyncedIds.isEmpty {
                                if let (model, isExisting) = self.chatRepository.getRoomSummaryModel(roomId: roomId, events: events) {
                                    var roomSummaryModel = model
                                    let resolver: ([String]) -> [String: ContactLite] = { ids in
                                        var out: [String: ContactLite] = [:]
                                        out.reserveCapacity(ids.count)
                                        for raw in ids {
                                            let uid = raw.formattedMatrixUserId
                                            out[uid] = ContactManager.shared.contact(for: uid)
                                                ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                        }
                                        return out
                                    }

                                    roomSummaryModel.update(
                                        stateEvents: events,
                                        timelineEvents: nil,
                                        unreadCount: nil,
                                        rehydrateWith: resolver
                                    )
                                    return Just((roomSummaryModel, isExisting))
                                        .setFailureType(to: APIError.self)
                                        .receive(on: DispatchQueue.main)
                                        .map { [weak self] summary, isExisting -> RoomModel? in
                                            guard let self = self else { return nil }
                                            self.chatRepository.updateRoom(room: summary, isExisting: isExisting)
                                            let model = self.chatRepository.upsertRoom(from: summary)
                                            return model
                                        }
                                        .eraseToAnyPublisher()
                                } else {
                                    return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
                                }
                            }

                            // Fetch only for unsynced members, then update contacts and build room
                            return self.userRepository.getUserProfiles(userIds: unsyncedIds)
                                .map { profiles in
                                    let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userID, $0) })
                                    for uid in unsyncedIds {
                                        guard let p = byId[uid.trimmedMatrixUserId] else { continue }
                                        
                                        if var contact = ContactManager.shared.contact(for: uid) {
                                            contact.userId = uid
                                            contact.displayName = p.name
                                            contact.emailAddresses = p.email.map { [$0] } ?? []
                                            contact.imageURL = p.profilePic
                                            contact.about = p.about
                                            contact.dob = p.dob
                                            contact.gender = p.gender
                                            contact.profession = p.profession
                                            contact.isSynced = true
                                            
                                            DBManager.shared.saveContacts(contacts: [contact])
                                        } else {
                                            let contactLite = ContactLite(
                                                userId: uid,
                                                fullName: "",
                                                phoneNumber: p.phone ?? "",
                                                emailAddresses: p.email.map { [$0] } ?? [],
                                                imageURL: p.mxcProfile,
                                                avatarURL: p.mxcProfile,
                                                displayName: p.name,
                                                about: p.about,
                                                dob: p.dob,
                                                gender: p.gender,
                                                profession: p.profession,
                                                isBlocked: false,
                                                isSynced: false,
                                                isOnline: false,
                                                lastSeen: nil
                                            )
                                            DBManager.shared.saveContact(contact: contactLite)
                                        }
                                    }
                                    return events
                                }
                                .receive(on: DispatchQueue.main)
                                .map { [weak self] updatedEvents -> RoomModel? in
                                    guard let self = self else { return nil }
                                    if let (model, isExisting) = self.chatRepository.getRoomSummaryModel(roomId: roomId, events: updatedEvents) {
                                        var summary = model
                                        let resolver: ([String]) -> [String: ContactLite] = { ids in
                                            var out: [String: ContactLite] = [:]
                                            out.reserveCapacity(ids.count)
                                            for raw in ids {
                                                let uid = raw.formattedMatrixUserId
                                                out[uid] = ContactManager.shared.contact(for: uid)
                                                    ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                            }
                                            return out
                                        }

                                        summary.update(
                                            stateEvents: updatedEvents,
                                            timelineEvents: nil,
                                            unreadCount: nil,
                                            rehydrateWith: resolver
                                        )
                                        self.chatRepository.updateRoom(room: summary, isExisting: isExisting)
                                        let model = self.chatRepository.upsertRoom(from: summary)
                                        return model
                                    }
                                    return nil
                                }
                                .eraseToAnyPublisher()
                        }
                        .eraseToAnyPublisher()

                case .unsuccess(let error):
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func updateMessageStatus(eventId: String, status: MessageStatus) {
        chatRepository.updateMessageStatus(eventId: eventId, status: status)
    }
    
    func sendTyping(roomId: String, userId: String, typing: Bool) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return chatRepository.sendTyping(roomId: roomId, userId: userId, typing: typing)
    }
    
    func getCommonGroups(with userId: String) -> AnyPublisher<[RoomModel], APIError> {
        chatRepository.getCommonGroups(with: userId)
    }
    
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String? = nil
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.deleteMessage(roomId: roomId, eventId: eventId, reason: reason)
    }
    
    func sendReaction(
        to message: ChatMessageModel,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.sendReaction(roomId: message.roomId, eventId: message.eventId, emoji: emoji)
    }
    
    func updateReaction(
        message: ChatMessageModel,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        let roomId = message.roomId
        
        // Find old reaction by this user
        if let oldReaction = message.reactions.first(where: { $0.userId == message.currentUserId }) {
            // 1. Redact old reaction, then 2. Send new
            return chatRepository.redactReaction(roomId: roomId, reactionEventId: oldReaction.eventId)
                .flatMap { _ in
                    self.chatRepository.sendReaction(roomId: roomId, eventId: message.eventId, emoji: emoji)
                }
                .eraseToAnyPublisher()
        } else {
            // No previous, just send new
            return chatRepository.sendReaction(roomId: roomId, eventId: message.eventId, emoji: emoji)
        }
    }
    
    func kickUserFromRoom(room: RoomModel, user: ContactModel, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        if let userId = user.userId {
            return chatRepository.kickFromRoom(roomId: room.id, userId: userId, reason: reason)
        }
        return Just<APIResult<MatrixEmptyResponse>>(.unsuccess(.userNotFound))
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func leaveRoom(room: RoomModel, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        chatRepository.leaveRoom(roomId: room.id, reason: reason)
    }
    
    func deleteRoom(room: RoomModel, reason: String) -> AnyPublisher<APIResult<EmptyResponse>, APIError> {
        let currentUserId = room.currentUser?.userId
        let otherMembers = room.activeParticipants.filter { $0.userId != currentUserId }
        
        let kickPublishers = otherMembers.map { member in
            kickUserFromRoom(room: room, user: member, reason: reason)
                .catch { _ in Just(.unsuccess(.unknown)).setFailureType(to: APIError.self) }
                .eraseToAnyPublisher()
        }
        
        return Publishers.MergeMany(kickPublishers)
            .collect()
            .flatMap { _ in
                self.userRepository.deleteRoom(roomId: room.id)
            }
            .flatMap { result -> AnyPublisher<APIResult<EmptyResponse>, APIError> in
                switch result {
                case .success:
                    return self.performRoomCleanup(room: room)
                        .map { _ in result }
                        .eraseToAnyPublisher()
                case .unsuccess:
                    return Just(result)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchAndUpdateRoomState(room: RoomModel) {
        chatRepository.getStateEvents(forRoom: room.id)
            .flatMap { [weak self] stateEvents -> AnyPublisher<Void, APIError> in
                guard let self = self else {
                    return Just(())
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }
                
                // member userIds (deduped)
                var seen = Set<String>()
                let memberUserIds: [String] = stateEvents
                    .filter { $0.type == EventType.roomMember.rawValue }
                    .compactMap { $0.stateKey }
                    .compactMap { uid in seen.insert(uid).inserted ? uid : nil }

                // fetch only if contact exists and is not yet synced
                let unsyncedIds: [String] = memberUserIds.compactMap { uid in
                    if let c = ContactManager.shared.contact(for: uid), c.isSynced == false { return uid }
                    return nil
                }

                // If nothing to fetch, just update room immediately
                if unsyncedIds.isEmpty {
                    if let (model, existing) = self.chatRepository.getRoomSummaryModel(roomId: room.id, events: stateEvents) {
                        var roomSummaryModel = model
                        let resolver: ([String]) -> [String: ContactLite] = { ids in
                            var out: [String: ContactLite] = [:]
                            out.reserveCapacity(ids.count)
                            for raw in ids {
                                let uid = raw.formattedMatrixUserId
                                out[uid] = ContactManager.shared.contact(for: uid)
                                    ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                            }
                            return out
                        }

                        roomSummaryModel.update(
                            stateEvents: stateEvents,
                            timelineEvents: nil,
                            unreadCount: nil,
                            rehydrateWith: resolver
                        )
                        self.chatRepository.updateRoom(room: roomSummaryModel, isExisting: existing)
                    }

                    return Just(())
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }

                // Fetch unsynced profiles, apply, mark synced, then update room
                return self.userRepository.getUserProfiles(userIds: unsyncedIds)
                    .mapError { $0 }
                    .map { profiles in
                        let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userID, $0) })

                        for uid in unsyncedIds {
                            guard let p = byId[uid.trimmedMatrixUserId] else { continue }
                            
                            if var contact = ContactManager.shared.contact(for: uid) {
                                contact.userId = uid
                                contact.displayName = p.name
                                contact.emailAddresses = p.email.map { [$0] } ?? []
                                contact.imageURL = p.profilePic
                                contact.about = p.about
                                contact.dob = p.dob
                                contact.gender = p.gender
                                contact.profession = p.profession
                                contact.isSynced = true
                                
                                DBManager.shared.saveContacts(contacts: [contact])
                            } else {
                                let contactLite = ContactLite(
                                    userId: uid,
                                    fullName: "",
                                    phoneNumber: p.phone ?? "",
                                    emailAddresses: p.email.map { [$0] } ?? [],
                                    imageURL: p.mxcProfile,
                                    avatarURL: p.mxcProfile,
                                    displayName: p.name,
                                    about: p.about,
                                    dob: p.dob,
                                    gender: p.gender,
                                    profession: p.profession,
                                    isBlocked: false,
                                    isSynced: false,
                                    isOnline: false,
                                    lastSeen: nil
                                )
                                DBManager.shared.saveContact(contact: contactLite)
                            }
                        }

                        if let (model, existing) = self.chatRepository.getRoomSummaryModel(roomId: room.id, events: stateEvents) {
                            var roomSummaryModel = model
                            let resolver: ([String]) -> [String: ContactLite] = { ids in
                                var out: [String: ContactLite] = [:]
                                out.reserveCapacity(ids.count)
                                for raw in ids {
                                    let uid = raw.formattedMatrixUserId
                                    out[uid] = ContactManager.shared.contact(for: uid)
                                        ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                }
                                return out
                            }

                            roomSummaryModel.update(
                                stateEvents: stateEvents,
                                timelineEvents: nil,
                                unreadCount: nil,
                                rehydrateWith: resolver
                            )
                            self.chatRepository.updateRoom(room: roomSummaryModel, isExisting: existing)
                        }
                        return ()
                    }
                    .eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    func fetchAndUpdateAllRoomsState(rooms: [RoomModel]) {
        for room in rooms {
            fetchAndUpdateRoomState(room: room)
        }
    }
    
    func performRoomCleanup(room: RoomModel) -> AnyPublisher<Void, APIError> {
        chatRepository.performRoomCleanup(roomId: room.id)
    }
    
    func inviteUsersToRoom(
        room: RoomModel,
        users: [ContactLite],
        reason: String = "Admin invited the user to the room"
    ) -> AnyPublisher<[(ContactLite, APIResult<MatrixEmptyResponse>)], APIError> {
        // For each user, call inviteUserToRoom and attach the user in the output
        let invitePublishers = users.map { user in
            self.inviteUserToRoom(room: room, user: user, reason: reason)
                .map { result in (user, result) }
                .eraseToAnyPublisher()
        }

        // Merge all invite publishers, collect results, and return
        return Publishers.MergeMany(invitePublishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func inviteUserToRoom(
        room: RoomModel,
        user: ContactLite,
        reason: String
    ) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        guard let userId = user.userId else {
            return Just<APIResult<MatrixEmptyResponse>>(.unsuccess(.userNotFound))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        return chatRepository.inviteToRoom(roomId: room.id, userId: userId, reason: reason)
            .flatMap { [weak self] result -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> in
                guard let self = self else {
                    return Just(.unsuccess(.unknown)).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                switch result {
                case .success:
                    // Fetch updated room state after successful invite
                    return self.chatRepository.getStateEvents(forRoom: room.id)
                        .map { stateEvents in
                            if let (model, existing) = self.chatRepository.getRoomSummaryModel(roomId: room.id, events: stateEvents) {
                                var roomSummaryModel = model
                                let resolver: ([String]) -> [String: ContactLite] = { ids in
                                    var out: [String: ContactLite] = [:]
                                    out.reserveCapacity(ids.count)
                                    for raw in ids {
                                        let uid = raw.formattedMatrixUserId
                                        out[uid] = ContactManager.shared.contact(for: uid)
                                            ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
                                    }
                                    return out
                                }

                                roomSummaryModel.update(
                                    stateEvents: stateEvents,
                                    timelineEvents: nil,
                                    unreadCount: nil,
                                    rehydrateWith: resolver
                                )
                                self.chatRepository.updateRoom(room: roomSummaryModel, isExisting: existing)
                            }
                            return .success(MatrixEmptyResponse())
                        }
                        .catch { error in
                            Just(.unsuccess(error)).setFailureType(to: APIError.self)
                        }
                        .eraseToAnyPublisher()
                case .unsuccess(let error):
                    return Just(.unsuccess(error))
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func toggleFavoriteRoom(roomID: String) {
        chatRepository.toggleFavoriteRoom(roomID: roomID)
    }
    
    func toggleDeletedRoom(roomID: String) {
        chatRepository.toggleDeletedRoom(roomID: roomID)
    }
    
    func toggleMutedRoom(roomID: String) {
        chatRepository.toggleMutedRoom(roomID: roomID)
    }
    
    func toggleLockedRoom(roomID: String) {
        chatRepository.toggleLockedRoom(roomID: roomID)
    }
    
    func toggleMarkedAsUnreadRoom(roomID: String) {
        chatRepository.toggleMarkedAsUnreadRoom(roomID: roomID)
    }
    
    func toggleBlockedRoom(roomID: String) {
        chatRepository.toggleBlockedRoom(roomID: roomID)
    }
    
    func getLockedRooms() -> [String] {
        chatRepository.getLockedRooms()
    }
    
    func getBlockedRooms() -> [String] {
        chatRepository.getBlockedRooms()
    }
    
    func getFavoriteRooms() -> [String] {
        chatRepository.getFavoriteRooms()
    }
    
    func getDeletedRooms() -> [String] {
        chatRepository.getDeletedRooms()
    }

    func getMutedRooms() -> [String] {
        chatRepository.getMutedRooms()
    }

    func getUnreadRooms() -> [String] {
        chatRepository.getUnreadRooms()
    }
    
    func updateRoomName(room: RoomModel, newName: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.updateRoomName(roomId: room.id, name: newName)
    }
    
    func updateRoomImage(room: RoomModel, newUrl: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        chatRepository.updateRoomImage(roomId: room.id, url: newUrl)
    }
    
    func fetchOlderMessages(roomId: String, pageSize: Int = 50) -> AnyPublisher<Bool, APIError> {
        chatRepository.fetchOlderMessages(roomId: roomId, pageSize: pageSize)
    }
}
