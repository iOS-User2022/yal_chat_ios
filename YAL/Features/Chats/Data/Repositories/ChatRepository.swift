//
//  ChatRepository.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/04/25.
//


import Combine
import Foundation
import RealmSwift

enum Direction: String, Codable {
    case forward = "f"
    case backward = "b"
}

final class ChatRepository: ChatRepositoryProtocol {
    private let matrixAPIManager: MatrixAPIManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var messageToken: NotificationToken?
    private var ephemeralToken: NotificationToken?
    private var roomToken: NotificationToken?
    
    // MARK: - Summary drain state
    private var pendingSummaries: [RoomSummaryModel] = []
    private var isDrainingSummaries = false
    private let roomDrainQueue = DispatchQueue(label: "rooms.drain.queue", qos: .userInitiated)
    private var hydratedSummaries: [RoomSummaryModel] = []
    private var hydratedSummariesById: [String: RoomSummaryModel] = [:]
    private var isCommittingSummaries = false
    private var roomsAccumulatedById: [String: RoomModel] = [:]
    private var hydrationRoomsById = [String: RoomModel]()
    private let hydrationState = DispatchQueue(label: "rooms.hydration.state")
    private let summaryQueue = DispatchQueue(
        label: "rooms.pipeline.state",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let summaryQueueKey = DispatchSpecificKey<UInt8>()

    private let hydrationQueue = DispatchQueue(label: "rooms.pipeline.hydration", qos: .userInitiated)
    private let repoQ = DispatchQueue(label: "yal.repo.chat", qos: .userInitiated)
    
    private var backfillInFlight = Set<String>()
    private let backfillQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "rooms.backfill.queue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 4
        return q
    }()
    private let backfillState = DispatchQueue(label: "rooms.backfill.state")
    private var expectedRoomsTotal = 0
    private let chatProcessQueue = DispatchQueue(label: "chat.process.queue", qos: .userInitiated)

    let profileSync: ProfileSyncCoordinator
    
    let hydrationTrigger = PassthroughSubject<Void, Never>()
    private var hydrationCancellable: AnyCancellable?

    private let redactionSubject = PassthroughSubject<String, Never>() // eventId
    var redactionPublisher: AnyPublisher<String, Never> {
        redactionSubject.eraseToAnyPublisher()
    }

    @Published var rooms: [RoomModel] = []
    var roomsPublisher: Published<[RoomModel]>.Publisher { $rooms }

    private let roomModelsSubject = CurrentValueSubject<[RoomModel], Never>([])
    var roomModelsPublisher: AnyPublisher<[RoomModel], Never> { $rooms.eraseToAnyPublisher() }

    private let inviteResponseSubject = PassthroughSubject<[String], APIError>()
    var inviteResponsePublisher: AnyPublisher<[String], APIError> {
        return inviteResponseSubject.eraseToAnyPublisher()
    }

    private let chatMessagesSubject = PassthroughSubject<[ChatMessageModel], Never>()
    var chatMessagesPublisher: AnyPublisher<[ChatMessageModel], Never> {
        return chatMessagesSubject.eraseToAnyPublisher()
    }

    private let ephemeralSubject = PassthroughSubject<ReceiptUpdate, Never>()
    var ephemeralPublisher: AnyPublisher<ReceiptUpdate, Never> {
        return ephemeralSubject.eraseToAnyPublisher()
    }
    
    private let typingSubject = PassthroughSubject<TypingUpdate, Never>()
    var typingPublisher: AnyPublisher<TypingUpdate, Never> {
        return typingSubject.eraseToAnyPublisher()
    }

    private let messageCountsSubject = CurrentValueSubject<[String: Int], Never>([:])
    var messageCountsPublisher: AnyPublisher<[String: Int], Never> {
        messageCountsSubject.eraseToAnyPublisher()
    }
    
    private let hydrationProgressSubject = CurrentValueSubject<(hydrated: Int, total: Int), Never>((0, 0))
    var hydrationProgressPublisher: AnyPublisher<(hydrated: Int, total: Int), Never> {
        hydrationProgressSubject.eraseToAnyPublisher()
    }

    private lazy var messagesBackfill = MessageBackfillCoordinator(api: matrixAPIManager, repo: self)

    
    private let messageBackfillProgressSubject = CurrentValueSubject<(done: Int, total: Int), Never>((0, 0))
    var messageBackfillProgressPublisher: AnyPublisher<(done: Int, total: Int), Never> {
        messageBackfillProgressSubject.eraseToAnyPublisher()
    }

    // keep track of rooms we still need to backfill
    private var messageBackfillTotalRooms: [String] = []
    private var messageBackfillDoneRooms = Set<String>()
    
    private var messageObservationEnabled = false
    private var activeRoomId: String? = nil
    private var didWarmCache = false
    
    @inline(__always)
    private func equalAsSet(_ a: [String], _ b: [String]) -> Bool { Set(a) == Set(b) }
    
    init(matrixAPIManager: MatrixAPIManagerProtocol, userRepository: UserRepository) {
        self.matrixAPIManager = matrixAPIManager
        self.profileSync = ProfileSyncCoordinator(userRepository: userRepository)
        summaryQueue.setSpecific(key: summaryQueueKey, value: 1)

        self.observeMessages()
        self.observeEphemeralEvents()
        self.observeRooms()
        self.observeProfileSyncNotifications()

        self.matrixAPIManager.syncResponsePublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Sync error in ChatRepository: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] response in
                switch response {
                case .success(let syncResponse):
                    self?.handleSyncResponse(syncResponse: syncResponse)
                case .unsuccess(let error):
                    print("Sync error: \(error.localizedDescription)")
                }
            })
            .store(in: &cancellables)

        self.matrixAPIManager.chatMessagesPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Chat sync error in ChatRepository: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] response in
                switch response {
                case .success(let syncResponse):
                    self?.handleChatSyncResponse(chatMessageResponse: syncResponse)
                    if !syncResponse.chunk.isEmpty,
                       let roomId = syncResponse.chunk.first?.roomId,
                        let end = syncResponse.end {
                        DBManager.shared.saveMessageSync(roomId: roomId, firstEvent: nil, lastEvent: end)
                    }
                case .unsuccess(let error):
                    print("Chat sync error: \(error.localizedDescription)")
                }
            })
            .store(in: &cancellables)
    }

    deinit {
        hydrationCancellable?.cancel()
        messageToken?.invalidate()
        ephemeralToken?.invalidate()
        roomToken?.invalidate()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
        print("ChatRepository deinit")
    }
    
    func getExistingRoomModel(roomId: String) -> RoomModel? {
        if let roomModel = self.roomsAccumulatedById[roomId] {
            return roomModel
        } else {
            print("Room \(roomId) not found in ChatRepository")
            return nil
        }
    }
    
    func observeMessages() {
        messageToken?.invalidate()

        guard let authSession = Storage.get(
            for: .authSession,
            type: .keychain,
            as: AuthSession.self
        ) else {
            return
        }

        let baseRealm = DBManager.shared.makeRealm()
        let results = baseRealm.objects(MessageObject.self)
            .sorted(byKeyPath: "timestamp", ascending: true)

        let queue = DispatchQueue(label: "messages.observe.queue", qos: .userInitiated)

        messageToken = results.observe(on: queue) { [weak self] changes in
            guard let self else { return }

            // read gate once
            let (enabled, roomFilter): (Bool, String?) = self.hydrationState.sync {
                (self.messageObservationEnabled, self.activeRoomId)
            }

            switch changes {

            case .initial(let collection):
                // ❗️Do NOT send initial batch unless enabled
                guard enabled else { return }

                let models: [ChatMessageModel] = collection
                    .filter { obj in
                        // if we have a roomFilter, only pass that room
                        if let roomId = roomFilter {
                            return obj.roomId == roomId
                        }
                        return true
                    }
                    .map { obj in
                        ChatMessageModel(
                            from: obj,
                            currentUserId: authSession.userId,
                            inReplyTo: nil
                        )
                    }

                guard !models.isEmpty else { return }

                self.chatMessagesSubject.send(models)

                let counts = Dictionary(grouping: models, by: { $0.roomId })
                    .mapValues { $0.count }
                self.messageCountsSubject.send(counts)

            case .update(let collection, _, let insertions, let modifications):
                guard enabled else { return }

                let changedIndices = insertions + modifications
                guard !changedIndices.isEmpty else { return }

                let realm = DBManager.shared.makeRealm()

                var replyIds: [String] = []
                replyIds.reserveCapacity(changedIndices.count)
                for idx in changedIndices {
                    let obj = collection[idx]
                    if let rid = obj.inReplyTo {
                        replyIds.append(rid)
                    }
                }

                var repliesById: [String: MessageObject] = [:]
                if !replyIds.isEmpty {
                    let replyObjects = realm.objects(MessageObject.self)
                        .filter("eventId IN %@", replyIds)
                    repliesById = Dictionary(uniqueKeysWithValues: replyObjects.map {
                        ($0.eventId, $0)
                    })
                }

                var changedModels: [ChatMessageModel] = []
                changedModels.reserveCapacity(changedIndices.count)

                for idx in changedIndices {
                    let obj = collection[idx]

                    // room filter
                    if let roomId = roomFilter, obj.roomId != roomId {
                        continue
                    }

                    var replyModel: ChatMessageModel? = nil
                    if let rid = obj.inReplyTo,
                       let replyObj = repliesById[rid] {
                        replyModel = ChatMessageModel(
                            from: replyObj,
                            currentUserId: authSession.userId,
                            inReplyTo: nil
                        )
                    }

                    let model = ChatMessageModel(
                        from: obj,
                        currentUserId: authSession.userId,
                        inReplyTo: replyModel
                    )
                    changedModels.append(model)
                }

                if !changedModels.isEmpty {
                    self.chatMessagesSubject.send(changedModels)
                }

            case .error(let error):
                print("Realm message observation error: \(error)")
            }
        }
    }
    
    func observeEphemeralEvents() {
        ephemeralToken?.invalidate()

        let realm = DBManager.shared.realm
        let results = realm.objects(MessageObject.self)
            .sorted(byKeyPath: "timestamp", ascending: true)

        ephemeralToken = results.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .update(let messages, _, _, _):
                for message in messages {
                    if let receiptsData = message.receipts,
                       let receipts = try? JSONDecoder().decode([MessageReadReceipt].self, from: receiptsData) {
                        let eventId = message.eventId
                        self.ephemeralSubject.send(ReceiptUpdate(eventId: eventId, receipts: receipts))
                    }
                }
            case .error(let error):
                print("Realm error observing receipts: \(error)")
            case .initial:
                break // Optional
            }
        }
    }
    
    private func observeProfileSyncNotifications() {
        NotificationCenter.default.addObserver(
            forName: .didSyncProfiles,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, let changedIds = note.object as? Set<String> else { return }

            // Update in-memory summaries under the summaryQueue
            summaryQueue.async { [weak self] in
                guard let self else { return }
                let values = Array(self.hydratedSummariesById.values)
                var updated: [RoomSummaryModel] = []
                updated.reserveCapacity(values.count)

                for var s in values {
                    s.applyUpdatedContacts(for: changedIds)
                    self.hydratedSummariesById[s.id] = s
                    updated.append(s)
                }

                // Patch live RoomModel immediately on MAIN (no heavy rehydrate)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    for s in updated {
                        Task { @MainActor in
                            self.applySummaryToRoom(s)
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func applySummaryToRoom(_ s: RoomSummaryModel) {
        if let existing = hydrationState.sync(execute: { hydrationRoomsById[s.id] }) {
            // Update in place
            s.applyFull(to: existing)
            upsertRoomInArray(existing)
            // Optional: persist (you already do this elsewhere; keep if you want DB to mirror UI)
            DBManager.shared.saveRoom(room: existing)
        } else {
            // Create a room from summary and register it
            let created = s.materializeRoomModel()
            roomsAccumulatedById[s.id] = created
            upsertRoomInArray(created)
            hydrationState.sync { hydrationRoomsById[s.id] = created }
            DBManager.shared.saveRoom(room: created)
        }
    }
        
    func observeRooms() {
        roomToken?.invalidate()

        let realm = DBManager.shared.realm
        let results = realm.objects(RoomSummaryObject.self)
            .sorted(byKeyPath: "lastServerTimestamp", ascending: false)

        let mapQueue = DispatchQueue(label: "rooms.observe.map", qos: .userInitiated)

        roomToken = results.observe(on: mapQueue) { [weak self] changes in
            guard let self else { return }

            switch changes {

            // First paint: keep your existing pipeline
            case .initial(let objs):
                guard let currentUserId = self.getCurrentUserContact()?.userId else { return }
                let summaries: [RoomSummaryModel] = objs.map { o in
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
                        participantsCount: o.numberOfParticipants,
                        serverTimestamp: o.lastServerTimestamp,
                        lastServerTimestamp: o.lastServerTimestamp,
                        creator: o.creator,
                        createdAt: o.createdAt,
                        isLeft: false,
                        isGroup: o.numberOfParticipants > 2,
                        admins: [],
                        joinedUserIds: self.decodeIds(o.joinedMembersData),
                        invitedUserIds: self.decodeIds(o.invitedMembersData),
                        leftUserIds: self.decodeIds(o.leftMembersData),
                        bannedUserIds: self.decodeIds(o.bannedMembersData),
                        opponentUserId: nil,
                        joinedMembers: [],
                        invitedMembers: [],
                        leftMembers: [],
                        bannedMembers: [],
                        participants: []
                    )
                }
                self.enqueueSummaries(summaries)
                self.startDrainingSummariesIfNeeded()

            case .update(let objs, _, let insertions, let modifications):
                guard let currentUserId = self.getCurrentUserContact()?.userId else { return }

                // Never cross queues with live Realm objects
                let frozen = objs.freeze()

                // Do all queue-protected book-keeping inside summaryQueue
                self.summaryQueue.async { [weak self] in
                    guard let self else { return }

                    // --- Deletions ---
                    let currentIds = Set(frozen.map { $0.id })
                    let previously = Set(self.summaryKeysSnapshot())
                    let removedIds = previously.subtracting(currentIds)

                    if !removedIds.isEmpty {
                        for id in removedIds { self.hydratedSummariesById.removeValue(forKey: id) }
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            self.rooms.removeAll { removedIds.contains($0.id) }
                            self.hydrationState.sync {
                                for id in removedIds { _ = self.hydrationRoomsById.removeValue(forKey: id) }
                                // progress total is unchanged; we’re just removing hydrated entries from cache
                                self.hydrationProgressSubject.send((self.hydrationRoomsById.count, self.expectedRoomsTotal))
                            }
                        }
                    }

                    // --- Insertions & Modifications → (re)enqueue for processing ---
                    var toEnqueue: [RoomSummaryModel] = []
                    toEnqueue.reserveCapacity(insertions.count + modifications.count)

                    // Insertions: build a fresh summary value
                    for idx in insertions {
                        let o = frozen[idx]
                        let s = self.makeSummaryModel(from: o, currentUserId: currentUserId)
                        toEnqueue.append(s)
                    }

                    // Modifications: patch existing; only enqueue if something really changed
                    for idx in modifications {
                        let o = frozen[idx]
                        let id = o.id
                       
                        if var existing = self.hydratedSummariesById[id] {
                            let (changed, _) = self.patchSummary(&existing, with: o)
                            guard changed else { continue }               // skip no-ops

                            // Save patched copy in memory so latest state is visible immediately
                            self.hydratedSummariesById[id] = existing

                            // Push through pipeline so hydrate→commit updates progress/UI in one place
                            toEnqueue.append(existing)
                        } else {
                            // We don't have it in memory yet: treat like insertion
                            let s = self.makeSummaryModel(from: o, currentUserId: currentUserId)
                            toEnqueue.append(s)
                        }
                    }

                    // Enqueue in one shot. If a summary with same id is already pending,
                    // your enqueueSummaries() replaces it (not duplicates).
                    if !toEnqueue.isEmpty {
                        self.enqueueSummaries(toEnqueue)
                        self.startDrainingSummariesIfNeeded()
                    }
                }

            case .error(let err):
                print("Realm room observation error: \(err)")
            }
        }
    }
    
    private func makeSummaryModel(from o: RoomSummaryObject, currentUserId: String) -> RoomSummaryModel {
        RoomSummaryModel(
            id: o.id,
            currentUserId: currentUserId,
            name: o.name,
            avatarUrl: o.avatarUrl,
            lastMessage: o.lastMessage,
            lastMessageType: o.lastMessageType,
            lastSender: o.lastSender,
            lastSenderName: o.lastSenderName,
            unreadCount: o.unreadCount,
            participantsCount: o.numberOfParticipants,
            serverTimestamp: o.lastServerTimestamp,
            lastServerTimestamp: o.lastServerTimestamp,
            creator: o.creator,
            createdAt: o.createdAt,
            isLeft: false,
            isGroup: o.numberOfParticipants > 2,
            admins: [], // fill later if you persist
            joinedUserIds: decodeIds(o.joinedMembersData),
            invitedUserIds: decodeIds(o.invitedMembersData),
            leftUserIds: decodeIds(o.leftMembersData),
            bannedUserIds: decodeIds(o.bannedMembersData),
            opponentUserId: nil,
            joinedMembers: [],
            invitedMembers: [],
            leftMembers: [],
            bannedMembers: [],
            participants: []
        )
    }
    
    private func patchSummary(
        _ s: inout RoomSummaryModel,
        with obj: RoomSummaryObject
    ) -> (changed: Bool, membershipChanged: Bool) {
        var changed = false
        var membershipChanged = false

        func set<T: Equatable>(_ keyPath: WritableKeyPath<RoomSummaryModel,T>, _ new: T) {
            if s[keyPath: keyPath] != new { s[keyPath: keyPath] = new; changed = true }
        }

        set(\.name, obj.name)
        set(\.avatarUrl, obj.avatarUrl)
        set(\.lastMessage, obj.lastMessage)
        set(\.lastMessageType, obj.lastMessageType)
        set(\.lastSenderName, obj.lastSenderName)
        set(\.unreadCount, obj.unreadCount)
        set(\.participantsCount, obj.numberOfParticipants)
        set(\.serverTimestamp, obj.lastServerTimestamp)
        set(\.lastServerTimestamp, obj.lastServerTimestamp)

        let joined  = decodeIds(obj.joinedMembersData)
        let invited = decodeIds(obj.invitedMembersData)
        let left    = decodeIds(obj.leftMembersData)
        let banned  = decodeIds(obj.bannedMembersData)

        if s.joinedUserIds  != joined  { s.joinedUserIds  = joined;  changed = true; membershipChanged = true }
        if s.invitedUserIds != invited { s.invitedUserIds = invited; changed = true; membershipChanged = true }
        if s.leftUserIds    != left    { s.leftUserIds    = left;    changed = true; membershipChanged = true }
        if s.bannedUserIds  != banned  { s.bannedUserIds  = banned;  changed = true; membershipChanged = true }

        return (changed, membershipChanged)
    }
    
    private func startDrainingSummariesIfNeeded() {
        summaryQueue.async { [weak self] in
            guard let self,
                  !self.isDrainingSummaries,
                  !self.pendingSummaries.isEmpty else { return }
            self.isDrainingSummaries = true
            self.roomDrainQueue.async { [weak self] in
                self?.drainNextSummary()
            }
        }
    }
    
    func hydrateRoomSummaries(_ items: [RoomSummaryModel]) {
        enqueueSummaries(items)
    }
    
    private func enqueueSummaries(_ items: [RoomSummaryModel]) {
        summaryQueue.async { [weak self] in
            guard let self else { return }
            // de-dupe by id
            for s in items {
                if let i = self.pendingSummaries.firstIndex(where: { $0.id == s.id }) {
                    self.pendingSummaries[i] = s
                } else {
                    self.pendingSummaries.append(s)
                }
            }
            
            // sort once off-main so drain order == UI order
            self.pendingSummaries.sort {
                let lt = $0.lastServerTimestamp ?? $0.serverTimestamp ?? 0
                let rt = $1.lastServerTimestamp ?? $1.serverTimestamp ?? 0
                return lt > rt
            }

            
            if !self.isDrainingSummaries {
                self.isDrainingSummaries = true
                self.roomDrainQueue.async { [weak self] in
                    self?.drainNextSummary()
                }
            }
        }
    }
    
    private func drainNextSummary() {
        guard let summary = pendingPopFirst() else {
            setIsDraining(false)
            return
        }

        hydrateSummary(summary) { [weak self] hydrated in
            guard let self else { return }

            // Save hydrated summary (this mutates arrays/dicts -> use barrier)
            self.summaryWrite { [weak self] in
                guard let self else { return }
                if let idx = self.hydratedSummaries.firstIndex(where: { $0.id == hydrated.id }) {
                    self.hydratedSummaries[idx] = hydrated
                } else {
                    self.hydratedSummaries.append(hydrated)
                }
                self.hydratedSummariesById[hydrated.id] = hydrated
            }

            self.scheduleSummaryCommitIfNeeded()

            self.roomDrainQueue.async { [weak self] in
                guard let self else { return }
                if self.hasPending() {
                    self.drainNextSummary()
                } else {
                    self.setIsDraining(false)
                }
            }
        }
    }

    private func hydrateSummary(
        _ summary: RoomSummaryModel,
        completion: @escaping (RoomSummaryModel) -> Void
    ) {
        hydrationQueue.async { [weak self] in
            guard let self else { return }
            var s = summary

            // RoomSummaryModel decides how to use the map; we just provide it
            s.hydrateContacts { ids -> [String: ContactLite] in
                self.makeContactMap(for: ids)
            }

            completion(s)
        }
    }

    private func makeContactMap(for ids: [String]) -> [String: ContactLite] {
        var out: [String: ContactLite] = [:]
        out.reserveCapacity(ids.count)
        var missing: Set<String> = []
        for id in ids {
            if let c = ContactManager.shared.contact(for: id) {
                // adapt to ContactLite if needed
                out[id] = c
            } else {
                out[id] = ContactLite(userId: id, fullName: "", phoneNumber: "")
                missing.insert(id)
            }
        }
        profileSync.enqueue(Array(missing))
        return out
    }

    @inline(__always)
    private func upsertRoomInArray(_ model: RoomModel) {
        if let idx = rooms.firstIndex(where: { $0.id == model.id }) {
            rooms[idx] = model
        } else {
            rooms.append(model)
        }
    }
    
    private func scheduleSummaryCommitIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isCommittingSummaries {
                self.isCommittingSummaries = true
                self.commitNextHydratedSummary()
            }
        }
    }
    
    private func commitNextHydratedSummary() {
        guard let s: RoomSummaryModel = summaryQueue.sync(execute: {
            guard !hydratedSummaries.isEmpty else { return nil }
            return hydratedSummaries.removeFirst()
        }) else {
            isCommittingSummaries = false
            return
        }
        
        // ContactLite -> ContactModel (you already added this)
        let joined  = s.joinedMembers.map(ContactModel.fromLite)
        let invited = s.invitedMembers.map(ContactModel.fromLite)
        let left    = s.leftMembers.map(ContactModel.fromLite)
        let banned  = s.bannedMembers.map(ContactModel.fromLite)
        
        // participants = joined ∪ invited (de-dupe by userId or phone fallback)
        let participants: [ContactModel] = {
            var dict: [String: ContactModel] = [:]
            for m in joined + invited {
                let key = (m.userId?.isEmpty == false) ? m.userId! : m.phoneNumber
                dict[key] = m
            }
            return Array(dict.values)
        }()
        
        if let existing = roomsAccumulatedById[s.id] {
            existing.applySummary(
                name: s.name,
                currentUserId: s.currentUserId,
                avatarUrl: s.avatarUrl,
                lastMessage: s.lastMessage,
                lastMessageType: s.lastMessageType,
                lastSenderName: s.lastSenderName,
                unreadCount: s.unreadCount,
                participantsCount: s.participantsCount,
                lastServerTimestamp: s.lastServerTimestamp,
                joinedMemberIds: s.joinedUserIds,
                invitedMemberIds: s.invitedUserIds,
                leftMemberIds: s.leftUserIds,
                bannedMemberIds: s.bannedUserIds
            )
            existing.joinedMembers = joined
            existing.invitedMembers = invited
            existing.leftMembers    = left
            existing.bannedMembers  = banned
            existing.participants   = participants
            
            upsertRoomInArray(existing)
            hydrationState.sync {
                hydrationRoomsById[s.id] = existing
                hydrationProgressSubject.send((hydrationRoomsById.count, expectedRoomsTotal))
            }
            DBManager.shared.saveRoom(room: existing)
        } else {
            let model = RoomModel(
                id: s.id,
                name: s.name,
                currentUserId: s.currentUserId,
                avatarUrl: s.avatarUrl,
                lastMessage: s.lastMessage,
                lastMessageType: s.lastMessageType ?? MessageType.text.rawValue,
                lastSenderName: s.lastSenderName,
                unreadCount: s.unreadCount,
                participantsCount: s.participantsCount,
                lastServerTimestamp: s.lastServerTimestamp,
                joinedMemberIds: s.joinedUserIds,
                invitedMemberIds: s.invitedUserIds,
                leftMemberIds: s.leftUserIds,
                bannedMemberIds: s.bannedUserIds
            )
            model.joinedMembers = joined
            model.invitedMembers = invited
            model.leftMembers    = left
            model.bannedMembers  = banned
            model.participants   = participants
            
            roomsAccumulatedById[s.id] = model
            upsertRoomInArray(model)
            hydrationState.sync {
                hydrationRoomsById[s.id] = model
                hydrationProgressSubject.send((hydrationRoomsById.count, expectedRoomsTotal))
            }
            DBManager.shared.saveRoom(room: model)
        }
                
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.summaryQueue.sync(execute: { !self.hydratedSummaries.isEmpty }) {
                self.commitNextHydratedSummary()
            } else {
                self.isCommittingSummaries = false
            }
            if rooms.count == expectedRoomsTotal {
                self.startBackfillForAllRooms()
            }
        }
    }
    
    func enableMessageObservation(for roomId: String) {
        hydrationState.sync {
            self.messageObservationEnabled = true
            self.activeRoomId = roomId
        }
    }
    
    func disableMessageObservation() {
        hydrationState.sync {
            self.messageObservationEnabled = false
            self.activeRoomId = nil
        }
    }
    
    func setExpectedRoomsIds(_ ids: [String]) {
        let total = ids.count
        expectedRoomsTotal = total
        messageBackfillTotalRooms = ids
        let current = hydrationProgressSubject.value.hydrated
        hydrationProgressSubject.send((current, total))
    }
    
    
    private func startBackfillForAllRooms() {
        let roomIds: [String] = summaryQueue.sync {
            Array(self.hydratedSummariesById.keys)
        }

        messageBackfillProgressSubject.send((self.messageBackfillDoneRooms.count, roomIds.count))

        for id in roomIds {
            startBackfillForRoom(roomId: id, pages: 1, pageSize: 10)
        }
    }

    
    private func startBackfillForRoom(
        roomId: String,
        pages: Int = 3,
        pageSize: Int = 100,
        dir: Direction = .backward
    ) {
        // Dedup: ensure only one backfill per room at a time
        var shouldEnqueue = false
        backfillState.sync {
            if !backfillInFlight.contains(roomId), !messageBackfillDoneRooms.contains(roomId) {
                backfillInFlight.insert(roomId)
                shouldEnqueue = true
            }
        }
        guard shouldEnqueue else { return }

        let startFrom = DBManager.shared.fetchMessageSync(for: roomId)?.firstEvent
        
        let delay = Double.random(in: 0.06...0.18)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
            self.backfillQueue.addOperation { [weak self] in
                guard let self else { return }
                let done = DispatchSemaphore(value: 0)
                
                var cancellable: AnyCancellable?
                
                cancellable = self.backfillSequential(
                    roomId: roomId,
                    pages: pages,
                    pageSize: pageSize,
                    dir: dir,
                    startFrom: startFrom
                )
                .subscribe(on: DispatchQueue.global(qos: .utility))
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink(
                    receiveCompletion: { [weak self] completion in
                        guard let self else {
                            done.signal()
                            return
                        }

                        self.backfillState.sync {
                            self.backfillInFlight.remove(roomId)
                        }

                        self.markMessageBackfillDone(roomId: roomId)

                        if case .failure(let e) = completion {
                            print("Backfill(\(roomId)) failed: \(e)")
                        }
                        done.signal()
                    },
                    receiveValue: { }
                )
                
                // Keep this OperationQueue slot occupied until the publisher completes.
                done.wait()
                cancellable?.cancel()
            }
        }
    }
    
    private func markMessageBackfillDone(roomId: String) {
        // If totals weren’t set, bail
        let totalsEmpty = backfillState.sync { self.messageBackfillTotalRooms.isEmpty }
        guard !totalsEmpty else { return }

        let (done, total): (Int, Int) = backfillState.sync {
            self.messageBackfillDoneRooms.insert(roomId)
            return (self.messageBackfillDoneRooms.count, self.messageBackfillTotalRooms.count)
        }

        // Publish on main (Combine UI consumers expect main)
        DispatchQueue.main.async { [weak self] in
            self?.messageBackfillProgressSubject.send((done, total))
        }
    }
    
    // Chain N pages strictly in sequence; each page is fed into your existing handler
    private func backfillSequential(
        roomId: String,
        pages: Int,
        pageSize: Int,
        dir: Direction,
        startFrom: String?
    ) -> AnyPublisher<Void, APIError> {
        guard pages > 0 else {
            return Just(())
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        let indices = Array(0..<pages)
        return indices.reduce(
            Just(startFrom).setFailureType(to: APIError.self).eraseToAnyPublisher()
        ) { upstream, _ in
            upstream
                .flatMap { token in
                    self.fetchMessagesPage(roomId: roomId, from: token, limit: pageSize, dir: dir)
                }
                .handleEvents(receiveOutput: { [weak self] (response, _) in
                    self?.handleChatSyncResponse(chatMessageResponse: response)

                    if let start = response.start, let end = response.end, dir == .backward {
                        DBManager.shared.saveMessageSync(roomId: roomId, firstEvent: end, lastEvent: start)
                    }
                })
                .map { $0.1 } // pass next token forward
                .eraseToAnyPublisher()
        }
        .map { _ in () }
        .eraseToAnyPublisher()
    }
    
    // Fetch a single page, unwrap to (response, nextToken)
    private func fetchMessagesPage(
        roomId: String,
        from: String?,
        limit: Int,
        dir: Direction
    ) -> AnyPublisher<(GetMessagesResponse, String?), APIError> {
        matrixAPIManager.fetchMessages(forRoom: roomId, from: from, limit: limit, dir: dir.rawValue)
            .tryMap { result -> (GetMessagesResponse, String?) in
                switch result {
                case .success(let res):
                    //print("Message fetched: \(roomId) - from: \(from ?? "")")
                    return (res, res.end)   // 'end' is next token
                case .unsuccess(let e): throw e
                }
            }
            .mapError { $0 as? APIError ?? .unknown }
            .eraseToAnyPublisher()
    }
    
    func fetchOlderMessages(roomId: String, pageSize: Int = 50) -> AnyPublisher<Bool, APIError> {
        let startFrom = DBManager.shared.fetchMessageSync(for: roomId)?.firstEvent

        return fetchMessagesPage(roomId: roomId, from: startFrom, limit: pageSize, dir: .backward)
            .handleEvents(receiveOutput: { [weak self] (response, _) in
                self?.handleChatSyncResponse(chatMessageResponse: response)

                if let end = response.end {
                    DBManager.shared.saveMessageSync(roomId: roomId, firstEvent: end, lastEvent: nil)
                }
            })
            .map { (response, _) in !response.chunk.isEmpty }
            .eraseToAnyPublisher()
    }
    
    private func handleSyncResponse(syncResponse: SyncResponse) {
        let nextBatch = syncResponse.nextBatch ?? ""
        DBManager.shared.saveRoomSync(nextBatch: nextBatch)
        
        let presenceMap = Dictionary(
            uniqueKeysWithValues: (syncResponse.presence?.events ?? [])
                .map { ($0.sender, $0) }
        )
        for (userId, presenceEvent) in presenceMap {
            if let userId = userId {
                ContactManager.shared.updatePresence(
                    for: userId,
                    isOnline: presenceEvent.content?.currentlyActive ?? false,
                    lastSeen: presenceEvent.content?.lastActiveAgo,
                    avatarURL: presenceEvent.content?.avatarURL,
                    statusMessage: presenceEvent.content?.statusMessage
                )
            }
        }
        
        let roomsDict = syncResponse.rooms?.join ?? [:]
        if let currentUserData = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            
            for (roomId, roomSummary) in roomsDict {
                // Check if we already have this room
                if var existingRoom: RoomSummaryModel = summaryGet(roomId) {
                    // Update existing room with new info
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
                    
                    summaryMutate(roomId) { s in
                        var s = s
                        s.update(
                            stateEvents: roomSummary.state?.events,
                            timelineEvents: roomSummary.timeline?.events,
                            unreadCount: roomSummary.unreadNotifications?.notificationCount,
                            rehydrateWith: resolver
                        )
                        // presence patches…
                        for i in s.participants.indices {
                            if let uid = s.participants[i].userId, let pres = presenceMap[uid] {
                                s.participants[i].setIsOnline(isOnline: pres.content?.currentlyActive ?? false)
                                s.participants[i].setLastSeen(lastSeen: pres.content?.lastActiveAgo ?? 0)
                                s.participants[i].setAvatarURL(avatarURL: pres.content?.avatarURL ?? "")
                                s.participants[i].setStatusMessage(statusMessage: pres.content?.statusMessage ?? "")
                            }
                        }
                        return s
                    }
//                    existingRoom.update(
//                        stateEvents: roomSummary.state?.events,
//                        timelineEvents: roomSummary.timeline?.events,
//                        unreadCount: roomSummary.unreadNotifications?.notificationCount,
//                        rehydrateWith: resolver
//                    )
//
//
//                    for i in existingRoom.participants.indices {
//                        let userId = existingRoom.participants[i].userId
//                        if let userId = userId, let presence = presenceMap[userId] {
//                            existingRoom.participants[i].setIsOnline(isOnline: presence.content?.currentlyActive ?? false)
//                            existingRoom.participants[i].setLastSeen(lastSeen: presence.content?.lastActiveAgo ?? 0)
//                            existingRoom.participants[i].setAvatarURL(avatarURL: presence.content?.avatarURL ?? "")
//                            existingRoom.participants[i].setStatusMessage(statusMessage: presence.content?.statusMessage ?? "")
//                        }
//                    }
                    updateRoom(room: existingRoom, isExisting: true)
                    
                    // Extract ephemeral events (receipts)
                    if let ephemeral = roomSummary.ephemeral?.events {
                        for event in ephemeral {
                            if event.type == "m.receipt" {
                                DBManager.shared.updateReceipts(
                                    forRoom: roomId,
                                    content: event.content,
                                    currentUserId: currentUserData.userId
                                )
                            }
                            if event.type == "m.typing" {
                                if case let .typing(typingtContent) = event.content {
                                    let typingUpdate = TypingUpdate(roomId: roomId, userIds: typingtContent.userIds)
                                    typingSubject.send(typingUpdate)
                                }
                            }
                        }
                    }
                    if let stateEvents = roomSummary.state?.events {
                        let memberIds = stateEvents
                            .filter { $0.type == EventType.roomMember.rawValue }
                            .compactMap { $0.stateKey }
                            .filter { !$0.isEmpty }
                        if !memberIds.isEmpty {
                            profileSync.enqueue(memberIds)
                        }
                    }
                }
            }
            
            // Create a list to hold the RoomInviteModels for invited rooms
            if let inviteList = syncResponse.rooms?.invite?.keys.map({ $0 }) {
                // Send the updated invite list to the inviteResponseSubject for invited rooms
                inviteResponseSubject.send(inviteList)
            }
            
            if let leftRooms = syncResponse.rooms?.leave?.keys.map({ $0 }) {
                for leftRoomId in leftRooms {
                    if var roomSummary = hydratedSummariesById[leftRoomId] {
                        roomSummary.isLeft = true
                        updateRoom(room: roomSummary, isExisting: true)
                    }
                }
            }
        }
    }

    func updateRoom(room: RoomSummaryModel, isExisting: Bool) {
        summaryWrite { [weak self] in
            self?.hydratedSummariesById[room.id] = room
        }
        DBManager.shared.saveRoomSummary(room)
    }
    
    func handleChatSyncResponse(chatMessageResponse: GetMessagesResponse) {
        guard
            !chatMessageResponse.chunk.isEmpty,
            let roomId = chatMessageResponse.chunk.first?.roomId
        else { return }

        //print("Messages fetched for room: \(roomId) - count: \(chatMessageResponse.chunk.count)")

        let members: [ContactModel] = self.roomsAccumulatedById[roomId]?.participants ?? []

        chatProcessQueue.async { [weak self] in
            guard let self else { return }

            autoreleasepool {
                var seenOrSaved = Set<String>()
                var lastBody: String?
                var lastSender: String?
                var lastTs: Int64 = 0
                var lastMessageType = MessageType.text.rawValue

                for event in chatMessageResponse.chunk {
                    autoreleasepool {
                        switch event.type {
                        case "m.room.redaction":
                            if let redacts = event.redacts {
                                DBManager.shared.markMessageRedacted(eventId: redacts)
                                self.redactionSubject.send(redacts)
                                seenOrSaved.insert(redacts)
                            }

                        case "m.reaction":
                            guard
                                let relatesTo = event.content?.relatesTo,
                                let emojiKey = relatesTo.key,
                                let reactionEventId = event.eventId,
                                let sender = event.sender,
                                let ts = event.originServerTs
                            else { break }

                            let originalEventId = relatesTo.eventId ?? ""
                            DBManager.shared.addReactionToMessage(
                                messageEventId: originalEventId,
                                reactionEventId: reactionEventId,
                                userId: sender,
                                emojiKey: emojiKey,
                                timestamp: ts
                            )
                            seenOrSaved.insert(reactionEventId)

                        case "m.room.message":
                            let isRedacted = event.unsigned?.redactedBy != nil || event.unsigned?.redactedBecause != nil
                            guard !isRedacted, let body = event.content?.body else { break }
                            guard let eventId = event.eventId else { break }

                            let replyEventId = event.content?.relatesTo?.inReplyTo?.eventId

                            if !seenOrSaved.contains(eventId) {
                                if let saved = DBManager.shared.getMessageIfExists(eventId: eventId) {
                                    if saved.content != body {
                                        saved.content = body
                                        DBManager.shared.updateMessage(message: saved, inRoom: roomId, inReplyTo: replyEventId)
                                    }
                                } else {
                                    if let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
                                        let model = ChatMessageModel(
                                            message: event,
                                            roomId: roomId,
                                            currentUserId: authSession.userId,
                                            members: members
                                        )
                                        DBManager.shared.saveMessage(message: model, inRoom: roomId, inReplyTo: replyEventId)
                                    }
                                }
                                seenOrSaved.insert(eventId)
                            }

                            if let ts = event.originServerTs, ts >= lastTs {
                                lastTs = ts
                                lastBody = body
                                lastSender = event.sender
                                lastMessageType = event.content?.msgType ?? MessageType.text.rawValue
                            }

                        default:
                            break
                        }
                    }
                }

                if let body = lastBody {
                    let ts = (lastTs == 0) ? Date().millisecondsSince1970 : lastTs

                    let resolvedSenderName: String? = lastSender.flatMap { uid in
                        if let c = ContactManager.shared.contact(for: uid) {
                            return c.fullName ?? c.phoneNumber
                        }
                        return uid
                    }

                    var updated: RoomSummaryModel?
                    self.summaryQueue.sync {
                        guard var s = self.hydratedSummariesById[roomId] else { return }
                        s.lastMessage       = body
                        s.lastMessageType   = lastMessageType
                        s.lastSender        = lastSender
                        if let name = resolvedSenderName { s.lastSenderName = name }
                        s.serverTimestamp   = ts
                        s.lastServerTimestamp = ts
                        self.hydratedSummariesById[roomId] = s
                        updated = s
                    }

                    if let s = updated {
                        DBManager.shared.saveRoomSummary(s)

                        Task { @MainActor in
                            let live: RoomModel? = self.hydrationState.sync { self.hydrationRoomsById[roomId] }
                                ?? self.rooms.first(where: { $0.id == roomId })
                            guard let room = live else { return }

                            // update only cheap header fields
                            room.lastMessage      = body
                            room.lastMessageType  = lastMessageType
                            room.lastSenderName   = resolvedSenderName ?? lastSender
                            room.serverTimestamp  = ts   // (or lastServerTimestamp if that’s your canonical sort key)

                            // unread logic: bump only if it's not our own message and the room isn't actively open
                            let isViewingThisRoom: Bool = self.hydrationState.sync {
                                self.messageObservationEnabled && (self.activeRoomId == roomId)
                            }
                            if let currentUserId = self.getCurrentUserContact()?.userId,
                               lastSender != currentUserId,
                               !isViewingThisRoom
                            {
                                room.unreadCount = max(0, room.unreadCount + 1)
                                room.isRead = false
                            }

                            // keep array + ordering consistent
                            self.upsertRoomInArray(room)
                            self.resortRoomsStable()
                        }
                    }
                }
            }
        }
    }

    func banFromRoom(roomId: String, userId: String, reason: String?) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.banFromRoom(roomId: roomId, userId: userId)
    }

    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.unbanFromRoom(roomId: roomId, userId: userId)
    }
    
    // MARK: - Room notifications (mute/unmute via Push Rules)
    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.muteRoomNotifications(roomId: roomId, duration: duration)
            .map { result in
                return result
            }
            .eraseToAnyPublisher()
    }
    
    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.unmuteRoomNotifications(roomId: roomId)
            .map { result in
                return result
            }
            .eraseToAnyPublisher()
    }

    // Restore session using access token
    func restoreSession(accessToken: String) {
        matrixAPIManager.restoreSession(accessToken: accessToken)
    }
    
    func startSync() {
        repoQ.async { [weak self] in
            guard let self else { return }
            let nextBatchToken = DBManager.shared.fetchRoomSync()?.nextBatch
            self.matrixAPIManager.startSyncPolling(nextBatch: nextBatchToken)
        }
    }

    // Send message implementation (patched for optimistic update)
    func sendMessage(message: ChatMessageModel) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        guard let messageRequest = MessageRequest(from: message) else {
            return Just<APIResult<SendMessageResponse>>(.unsuccess(APIError.badRequest))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        // Optimistic update
        if var roomSummaryModel = self.hydratedSummariesById[message.roomId] {
            roomSummaryModel.lastMessage = message.content
            roomSummaryModel.lastMessageType = message.msgType
            roomSummaryModel.lastSender = message.sender
            roomSummaryModel.serverTimestamp = Date().millisecondsSince1970
            updateRoom(room: roomSummaryModel, isExisting: true)
        }

        return matrixAPIManager.sendMessage(roomId: message.roomId, message: messageRequest)
    }
    
    func sendMessage(message: ChatMessageModel, roomId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        guard let messageRequest = MessageRequest(from: message) else {
            return Just<APIResult<SendMessageResponse>>(.unsuccess(APIError.badRequest))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        //  Optimistic update
        if var roomSummaryModel = self.hydratedSummariesById[roomId] {
            roomSummaryModel.lastMessage = message.content
            roomSummaryModel.lastMessageType = message.msgType
            roomSummaryModel.lastSender = message.sender
            roomSummaryModel.serverTimestamp = Date().millisecondsSince1970
            updateRoom(room: roomSummaryModel, isExisting: true)
        }

        return matrixAPIManager.sendMessage(roomId: roomId, message: messageRequest)
    }
    
    func createRoom(currentUser: String, invitees: [String], roomName: String?, roomDisplayImageUrl: String?) -> AnyPublisher<APIResult<CreateRoomResponse>, APIError> {
        if let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession?.self),
            let currentUserId = authSession?.userId {
            return matrixAPIManager.createRoom(
                createRoomRequest: CreateRoomRequest(
                    preset: .trustedPrivateChat,
                    visibility: .private_room,
                    roomVersion: .v1,
                    invitee: invitees,
                    currentUserId: currentUserId,
                    roomName: roomName,
                    roomDisplayImageUrl: roomDisplayImageUrl
                )
            )
        } else {
            return Just<APIResult<CreateRoomResponse>>(.unsuccess(APIError.userNotFound))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
    }
    
    func joinRoom(roomId: String) -> AnyPublisher<APIResult<JoinRoomResponse>, APIError> {
        return matrixAPIManager.joinRoom(roomId: roomId)
    }
    
    func getMessages(fromRoom roomId: String, limit: Int = 100) {
        let chachedMessages: [ChatMessageModel] = DBManager.shared.fetchMessages(inRoom: roomId)
        if !chachedMessages.isEmpty {
            chatMessagesSubject.send(chachedMessages)
        }
        
        let lastMessageEventId: String? = DBManager.shared.fetchMessageSync(for: roomId)?.lastEvent
        matrixAPIManager.startSyncMesages(forRoom: roomId, lastMessageEventId: lastMessageEventId)
    }
    
    func banFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.banFromRoom(roomId: roomId, userId: userId)
            .map { [weak self] result in
                guard case .success = result,
                      var roomSummaryModel = self?.getExistingRoomSummaryModel(roomId: roomId) else {
                    return result
                }
                // Update local membership to banned
                roomSummaryModel.applyMembershipChange(userId: userId, membership: .ban)
                self?.updateRoom(room: roomSummaryModel, isExisting: true)
                return result
            }
            .eraseToAnyPublisher()
    }
    
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.leaveRoom(roomId: roomId)
    }
    
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.forgetRoom(roomId: roomId)
    }
    
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)? = nil) -> AnyPublisher<APIResult<URL>, APIError> {
        return matrixAPIManager.uploadMedia(fileURL: fileURL, fileName: fileName, mimeType: mimeType, onProgress: onProgress)
    }
    
    func downloadMediaForMessage(
        mxcUrl: String,
        fileName: String,
        onProgress: ((Double) -> Void)?
    ) -> AnyPublisher<APIResult<URL>, APIError> {
        matrixAPIManager.downloadMediaFile(
            mxcUrl: mxcUrl,
            onProgress: onProgress
        )
    }
    
    func getJoinedRooms() -> AnyPublisher<APIResult<JoinedRooms>, APIError> {
        matrixAPIManager.getJoinedRooms()
    }
    
    func getStateEvents(forRoom roomId: String) -> AnyPublisher<[Event], APIError> {
        matrixAPIManager.getRoomState(roomId: roomId)
            .tryMap { apiResult in
                switch apiResult {
                case .success(let events):
                    return events
                case .unsuccess(let error):
                    throw error
                }
            }
            .mapError { $0 as? APIError ?? .unknown }
            .eraseToAnyPublisher()
    }
    
    func roomsSnapshot() -> [RoomModel] {
        resortRoomsStable()
        return rooms
    }

    func warmCacheIfNeeded(shouldWarmCache: Bool = false) -> AnyPublisher<Void, Never> {
        guard !didWarmCache || shouldWarmCache else { return Just(()).eraseToAnyPublisher() }
        didWarmCache = true
        return loadCachedRooms()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    func loadCachedRooms() -> AnyPublisher<[RoomSummaryModel], Never> {
        Deferred {
            Future<[RoomSummaryModel], Never> { promise in
                DispatchQueue.global(qos: .userInitiated).async {
                    let snaps: [RoomSummaryModel] = DBManager.shared.fetchRooms() ?? []
                    let sorted = snaps.sorted { ($0.lastServerTimestamp ?? 0) > ($1.lastServerTimestamp ?? 0) }
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        let roomModels = sorted.map { $0.materializeRoomModel() }
                        self.rooms = roomModels
                    }
                    promise(.success(sorted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchFullRoomSummaries(
        ids: [String],
        includeContacts: Bool
    ) -> [RoomSummaryModel] {

        let resolver: ((String) -> ContactLite)? = includeContacts ? { [weak self] userId in
            guard let self = self else {
                return ContactLite(userId: userId, fullName: "", phoneNumber: "")
            }
            return self.makeContactMap(for: [userId])[userId]
            ?? ContactLite(userId: userId, fullName: "", phoneNumber: "")
        } : nil

        let full = DBManager.shared.fetchFullRoomSummaries(
            ids: ids,
            limit: ids.count,
            sortKey: "lastServerTimestamp",
            ascending: false,
            includeContacts: includeContacts,
            resolveContact: resolver
        )

        summaryQueue.async { [weak self] in
            guard let self else { return }

            for s in full {
                self.hydratedSummariesById[s.id] = s
            }

            self.enqueueSummaries(full)
            self.startDrainingSummariesIfNeeded()
        }

        return full
    }
    

//    func loadCachedRooms() -> AnyPublisher<[RoomSummaryModel], Never> {
//        Deferred {
//            Future<[RoomSummaryModel], Never> { promise in
//                DispatchQueue.global(qos: .userInitiated).async {
//                    let snaps: [RoomSummaryModel] = DBManager.shared.fetchRooms() ?? []
//                    
//                    let allIds = Array(Set(snaps.flatMap { $0.joinedUserIds + $0.invitedUserIds + $0.leftUserIds + $0.bannedUserIds }))
//                    let resolvedMap: [String: ContactLite] = {
//                        var out: [String: ContactLite] = [:]
//                        out.reserveCapacity(allIds.count)
//                        for raw in allIds {
//                            let uid = raw.formattedMatrixUserId
//                            out[uid] = ContactManager.shared.contact(for: uid)
//                            ?? ContactLite(userId: uid, fullName: "", phoneNumber: "")
//                        }
//                        return out
//                    }()
//                    
//                    var hydrated = snaps
//                    for i in hydrated.indices {
//                        hydrated[i].hydrateContacts { ids in
//                            var m: [String: ContactLite] = [:]
//                            m.reserveCapacity(ids.count)
//                            for id in ids { m[id.formattedMatrixUserId] = resolvedMap[id.formattedMatrixUserId] }
//                            return m
//                        }
//                    }
//                    
//                    DispatchQueue.main.async {
//                        // Materialize heavy models on main
//                        let roomModels = hydrated.map { $0.materializeRoomModel() }
//                        // Push to your in-memory list (RoomService/VM)
//                        self.rooms = roomModels
//                        self.resortRoomsStable()
//                        promise(.success(hydrated))
//                    }
//                }
//            }
//        }
//        .eraseToAnyPublisher()
//    }
    
    func hydrateRooms(snaps: [RoomModel]) {
        let roomById = Dictionary(uniqueKeysWithValues: snaps.map { ($0.id, $0) })
        let hydrationQueue = DispatchQueue(label: "hydrations.consumer", qos: .userInitiated)
        
        DBManager.shared.streamRoomHydrations(sortKey: "lastServerTimestamp", ascending: false, limit: nil, batchSize: 1, batchDelay: 1.1)
            .receive(on: hydrationQueue)       // sink on bg
            .sink { [weak self] batch in
                guard self != nil else { return }
                for payload in batch {
                    guard let room = roomById[payload.id] else { continue }
                    
                    DispatchQueue.main.async {
                        room.hydrate(
                            currentUser: payload.currentUser,
                            creator: payload.creator,
                            createdAt: payload.createdAt,
                            avatarUrl: payload.avatarUrl,
                            lastMessage: payload.lastMessage,
                            lastSender: payload.lastSender,
                            lastSenderName: payload.lastSenderName,
                            unreadCount: payload.unreadCount,
                            joinedMembers: payload.joinedMembers,
                            invitedMembers: payload.invitedMembers,
                            leftMembers: payload.leftMembers,
                            bannedMembers: payload.bannedMembers,
                            admins: payload.admins,
                            stateEvents: payload.stateEvents,
                            serverTimestamp: payload.serverTimestamp,
                            lastServerTimestamp: payload.lastServerTimestamp
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func getRoomSummaryModel(roomId: String, events: [Event]) -> (RoomSummaryModel, Bool)? {
        if let roomSummaryModel = getExistingRoomSummaryModel(roomId: roomId) {
            return (roomSummaryModel, true)
        } else {
            guard let currentUser = getCurrentUserContact() else { return nil }
            let newRoomSummaryModel = RoomSummaryModel.from(roomId: roomId, stateEvents: events, currentUserId: currentUser.id)
            return (newRoomSummaryModel, false)
        }
    }
    
    @MainActor
    func upsertRoom(from summary: RoomSummaryModel) -> RoomModel {
        if let existing = rooms.first(where: { $0.id == summary.id }) {
            let updated = summary.materializeRoomModel(existing: existing)
            upsertRoomInArray(updated)
            return updated
        } else {
            let created = summary.materializeRoomModel()
            upsertRoomInArray(created)
            return created
        }
    }
    
    func upsertRoomSummary(
        roomId: String,
        stateEvents: [Event],
        timelineEvents: [Event]? = nil,
        unreadCount: Int = 0
    ) {
        guard let currentUserId = getCurrentUserContact()?.userId else { return }
        
        // Build snapshot (IDs only) using the same rules as RoomModel
        let summary = RoomSummaryAdapter.make(
            roomId: roomId,
            stateEvents: stateEvents,
            timelineEvents: timelineEvents,
            currentUserId: currentUserId,
            unreadCount: unreadCount
        )
        
        // Upsert into Realm. DBManager handles create vs update.
        DBManager.shared.saveRoomSummary(summary)
    }
    
    func getExistingRoomSummaryModel(roomId: String) -> RoomSummaryModel? {
        summarySync { hydratedSummariesById[roomId] }
    }
    
    private func extractRoomMemberUserIds(from events: [Event]) -> [String] {
        return events
            .filter { $0.type == EventType.roomMember.rawValue }
            .compactMap { $0.stateKey }
    }

    private func updateRoomCacheIfNeeded(roomId: String, events: [Event], currentUser: ContactModel) -> RoomModel? {
        if let index = self.rooms.firstIndex(where: { $0.id == roomId }) {
            self.rooms[index].update(
                state: StateEvents(events: events),
                timeline: nil,
                summary: nil,
                unreadNotifications: nil
            )
            return self.rooms[index]
        } else {
            return RoomModel(roomId: roomId, stateEvents: events, currentUser: currentUser)
        }
    }
    
    func getCurrentUserContact() -> ContactLite? {
        if let currentUserData = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self),
           let phoneNumber = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self),
           let profile = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self) {
            
            let currentUserContactLite = ContactLite(
                userId: currentUserData.userId,
                fullName: profile.name,
                phoneNumber: phoneNumber
            )
            
            return currentUserContactLite
        }
        return nil
    }
    
    // Function to update rooms with the new response data
    func updateRooms(with newRooms: [RoomSummaryModel]) {
        for updatedRoom in newRooms {
            if var existingRoom = getExistingRoomSummaryModel(roomId: updatedRoom.id) {
                // mutate the local copy
                if existingRoom.name != updatedRoom.name { existingRoom.name = updatedRoom.name }
                if existingRoom.participants.count != updatedRoom.participants.count {
                    existingRoom.participants = updatedRoom.participants
                }
                let presenceChanged = zip(existingRoom.participants, updatedRoom.participants)
                    .contains { $0.isOnline != $1.isOnline || $0.lastSeen != $1.lastSeen }
                if presenceChanged { existingRoom.participants = updatedRoom.participants }
                if existingRoom.lastMessage != updatedRoom.lastMessage { existingRoom.lastMessage = updatedRoom.lastMessage }
                if existingRoom.unreadCount != updatedRoom.unreadCount { existingRoom.unreadCount = updatedRoom.unreadCount }
                if existingRoom.avatarUrl != updatedRoom.avatarUrl { existingRoom.avatarUrl = updatedRoom.avatarUrl }

                updateRoom(room: existingRoom, isExisting: true)
            } else {
                updateRoom(room: updatedRoom, isExisting: false)
            }
        }
        resortRoomsStable()
    }
    
    func sendReadMarker(
        roomId: String,
        fullyReadEventId: String?,
        readEventId: String?,
        readPrivateEventId: String?
    ) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.sendReadMarker(
            roomId: roomId,
            fullyReadEventId: fullyReadEventId,
            readEventId: readEventId,
            readPrivateEventId: readPrivateEventId
        )
    }
    
    func updateMessageStatus(eventId: String, status: MessageStatus) {
        DBManager.shared.updateMessageStatus(eventId: eventId, status: status)
    }
    
    func sendTyping(roomId: String, userId: String, typing: Bool) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return matrixAPIManager.sendTyping(roomId: roomId, userId: userId, typing: typing, timeout: 3000)
    }
    
    func getCommonGroups(with userId: String) -> AnyPublisher<[RoomModel], APIError> {
        let currentUserId = getCurrentUserContact()?.userId ?? ""

        return Future<[RoomModel], APIError> { [weak self] promise in
            guard let self = self else {
                promise(.success([]))
                return
            }

            let shared = rooms.filter { room in
                room.isGroup &&
                room.participants.contains(where: { $0.userId == userId }) &&
                room.participants.contains(where: { $0.userId == currentUserId })
            }
            promise(.success(shared))
        }
        .eraseToAnyPublisher()
    }
    
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String? = nil
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        matrixAPIManager.deleteMessage(roomId: roomId, eventId: eventId, reason: reason)
    }
    
    func sendReaction(
        roomId: String,
        eventId: String,
        emoji: Emoji
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        matrixAPIManager.sendReaction(roomId: roomId, eventId: eventId, emoji: emoji)
    }
    
    func redactReaction(roomId: String, reactionEventId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        matrixAPIManager.redactReaction(roomId: roomId, reactionEventId: reactionEventId)
    }
    
    func kickFromRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.kickFromRoom(roomId: roomId, userId: userId, reason: reason)
            .map { [weak self] result in
                guard case .success = result,
                      var roomSummaryModel = self?.getExistingRoomSummaryModel(roomId: roomId) else {
                    return result
                }
                // Matrix "kick" results in membership = "leave"
                roomSummaryModel.applyMembershipChange(userId: userId, membership: .leave)
                self?.updateRoom(room: roomSummaryModel, isExisting: true)
                return result
            }
            .eraseToAnyPublisher()
    }
    
    func leaveRoom(roomId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.leaveRoom(roomId: roomId, reason: reason)
    }
    
    func performRoomCleanup(roomId: String) -> AnyPublisher<Void, APIError> {
        Future { [self] promise in
            DBManager.shared.deleteRoomById(roomId: roomId)
            rooms.removeAll { $0.id == roomId }
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    func inviteToRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        matrixAPIManager.inviteToRoom(roomId: roomId, userId: userId, reason: reason)
    }
    
    func toggleFavoriteRoom(roomID: String) {
        var favorites = getFavoriteRooms()
        if let idx = favorites.firstIndex(of: roomID) {
            // Remove if present
            favorites.remove(at: idx)
        } else {
            // Append if not present
            favorites.append(roomID)
        }
        saveFavoriteRooms(favorites)
    }
    
    func toggleMarkedAsUnreadRoom(roomID: String) {
        var unreads = getUnreadRooms()
        if let idx = unreads.firstIndex(of: roomID) {
            unreads.remove(at: idx)
        } else {
            unreads.append(roomID)
        }
        saveMarkedAsUnreadRooms(unreads)
    }
    
    func toggleBlockedRoom(roomID: String) {
        var unreads = getBlockedRooms()
        if let idx = unreads.firstIndex(of: roomID) {
            unreads.remove(at: idx)
        } else {
            unreads.append(roomID)
        }
        saveBlockedRooms(unreads)
    }
    
    func toggleMutedRoom(roomID: String) {
        var muteds = getMutedRooms()
        if let idx = muteds.firstIndex(of: roomID) {
            muteds.remove(at: idx)
        } else {
            muteds.append(roomID)
        }
        saveMutedRooms(muteds)
    }
    
    func toggleLockedRoom(roomID: String) {
        var muteds = getLockedRooms()
        if let idx = muteds.firstIndex(of: roomID) {
            muteds.remove(at: idx)
        } else {
            muteds.append(roomID)
        }
        saveLockedRooms(muteds)
    }
    
    func toggleDeletedRoom(roomID: String) {
        var deleteds = getDeletedRooms()
        if let idx = deleteds.firstIndex(of: roomID) {
            deleteds.remove(at: idx)
        } else {
            deleteds.append(roomID)
        }
        saveDeletedRooms(deleteds)
    }

    func getFavoriteRooms() -> [String] {
        Storage.get(for: .favoriteRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }

    func getUnreadRooms() -> [String] {
        Storage.get(for: .unreadRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }
    
    func getMutedRooms() -> [String] {
        Storage.get(for: .mutedRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }
    
    func getLockedRooms() -> [String] {
        Storage.get(for: .lockedRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }
    
    func getBlockedRooms() -> [String] {
        Storage.get(for: .blockedRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }
    
    func getDeletedRooms() -> [String] {
        Storage.get(for: .deletedRoomIDs, type: .userDefaults, as: [String].self) ?? []
    }

    private func saveFavoriteRooms(_ rooms: [String]) {
        // Always save the updated full list
        Storage.save(rooms, for: .favoriteRoomIDs, type: .userDefaults)
    }
    
    private func saveDeletedRooms(_ rooms: [String]) {
        Storage.save(rooms, for: .deletedRoomIDs, type: .userDefaults)
    }
    
    private func saveMutedRooms(_ rooms: [String]) {
        Storage.save(rooms, for: .mutedRoomIDs, type: .userDefaults)
    }
    
    private func saveLockedRooms(_ rooms: [String]) {
        Storage.save(rooms, for: .lockedRoomIDs, type: .userDefaults)
    }
    
    private func saveMarkedAsUnreadRooms(_ rooms: [String]) {
        Storage.save(rooms, for: .unreadRoomIDs, type: .userDefaults)
    }
    
    private func saveBlockedRooms(_ rooms: [String]) {
        Storage.save(rooms, for: .blockedRoomIDs, type: .userDefaults)
    }
    
    func updateRoomName(roomId: String, name: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        matrixAPIManager.updateRoomName(roomId: roomId, name: name)
            .map { [weak self] result in
                switch result {
                case .success(let response):
                    // Update the local room model
                    if var roomSummaryModel = self?.getExistingRoomSummaryModel(roomId: roomId) {
                        roomSummaryModel.name = name
                        self?.updateRoom(room: roomSummaryModel, isExisting: true)
                    }
                    return .success(response)
                case .unsuccess(let error):
                    return .unsuccess(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func updateRoomImage(roomId: String, url: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        matrixAPIManager.updateRoomImage(roomId: roomId, url: url)
            .map { [weak self] result in
                switch result {
                case .success(let response):
                    // Update the local room model
                    if var roomSummaryModel = self?.getExistingRoomSummaryModel(roomId: roomId) {
                        roomSummaryModel.avatarUrl = url
                        self?.updateRoom(room: roomSummaryModel, isExisting: true)
                    }
                    return .success(response)
                case .unsuccess(let error):
                    return .unsuccess(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Stable sorting helpers
    private func lastMessageTimestampFromDB(forRoom roomId: String) -> Int64 {
        let realm = DBManager.shared.realm
        if let last = realm.objects(MessageObject.self)
            .filter("roomId == %@", roomId)
            .sorted(byKeyPath: "timestamp", ascending: false)
            .first {
            return last.timestamp
        }
        return 0
    }
    
    private func activityTimestamp(for room: RoomModel) -> Int64 {
        if let ts = room.serverTimestamp, ts > 0 {
            return ts
        }
        return lastMessageTimestampFromDB(forRoom: room.id)
    }
    
    private func resortRoomsStable() {
        rooms.sort { lhs, rhs in
            let l = activityTimestamp(for: lhs)
            let r = activityTimestamp(for: rhs)
            if l != r { return l > r }
            return lhs.id < rhs.id
        }
    }
    
    // Decode `[String]` from Data safely
    private func decodeIds(_ data: Data?) -> [String] {
        guard let d = data, let arr = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return arr
    }

    // Resolve a ContactModel for a userId, fallback to a lightweight stub
    private func resolveContactModel(for userId: String) -> ContactLite {
        if let c = ContactManager.shared.contact(for: userId) { return c }
        return ContactLite(userId: userId, fullName: "", phoneNumber: "")
    }
    
    // MARK: - Thread-safe Summary access
    @inline(__always)
    private func summarySync<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: summaryQueueKey) != nil {
            return block()               // already on summaryQueue → run inline
        } else {
            return summaryQueue.sync(execute: block)
        }
    }
    
    private func summaryAsync(_ block: @escaping () -> Void) {
        summaryQueue.async(execute: block)
    }
    
    private func getSummary(id: String) -> RoomSummaryModel? {
        summarySync { hydratedSummariesById[id] }
    }
    
    private func setSummary(_ s: RoomSummaryModel) {
        summaryAsync { [weak self] in
            guard let self else { return }
            self.hydratedSummariesById[s.id] = s
        }
    }
    
    private func summaryKeysSnapshot() -> [String] {
        summarySync { Array(hydratedSummariesById.keys) }
    }

    // Barrier writes
    @inline(__always)
    private func summaryWrite(_ block: @escaping () -> Void) {
        summaryQueue.async(flags: .barrier, execute: block)
    }
    
    @inline(__always)
    private func summaryGet(_ id: String) -> RoomSummaryModel? {
        summarySync { hydratedSummariesById[id] }
    }

    @inline(__always)
    private func summaryPut(_ model: RoomSummaryModel) {
        summaryWrite { self.hydratedSummariesById[model.id] = model }
    }

    @inline(__always)
    private func summaryMutate(_ id: String, _ change: @escaping (RoomSummaryModel) -> RoomSummaryModel) {
        summaryWrite { [self] in
            if let current = hydratedSummariesById[id] {
                hydratedSummariesById[id] = change(current)
            }
        }
    }
    
    @inline(__always)
    private func summaryRead<T>(_ block: () -> T) -> T {
        summaryQueue.sync(execute: block)
    }

    @inline(__always)
    private func summarySyncWrite<T>(_ block: () -> T) -> T {
        summaryQueue.sync(flags: .barrier, execute: block)
    }

    @inline(__always)
    private func pendingPopFirst() -> RoomSummaryModel? {
        summarySyncWrite {
            pendingSummaries.isEmpty ? nil : pendingSummaries.removeFirst()
        }
    }

    @inline(__always)
    private func setIsDraining(_ v: Bool) {
        summarySyncWrite { isDrainingSummaries = v }
    }

    @inline(__always)
    private func hasPending() -> Bool {
        summaryRead { !pendingSummaries.isEmpty }
    }
}


// MARK: - Helpers
extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
