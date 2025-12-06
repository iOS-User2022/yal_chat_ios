//
//  RoomListViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//


import SwiftUI
import Combine

final class RoomListViewModel: ObservableObject {
    @Published var invites: [String] = []
    @Published var errorMessage: String? = nil
    @Published var participants: [ContactModel] = []
    @Published var invitedContacts: [ContactModel] = []
    @Published var selectedRoom: RoomModel?
    @Published var searchText: String = ""
    @Published var filteredRooms: [RoomModel] = []
    @Published var lockedRooms: [RoomModel] = []
    @Published var unFilteredRooms: [RoomModel] = []
    @Published var selectedFilter: ChatFilter = .all
    @Published var typingIndicators: [String: String] = [:]
    @Published var currentUser: ContactModel?
    @Published var blockedRooms: [RoomModel] = []

    @Published var isHydrating: Bool = false
    @Published var hydrationProgress: CGFloat = 0
    @Published var hydrationHydrated: Int = 0
    @Published var hydrationTotal: Int = 0
    
    @Published var isDownloadingMessages: Bool = false
    @Published var messageDownloadProgress: CGFloat = 0
    @Published var messageDownloadDone: Int = 0
    @Published var messageDownloadTotal: Int = 0
    
    private(set) var didLoadRooms: Bool = false
    private(set) var didLoadMessages: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var seenIDs = Set<String>()
    private var byId: [String: RoomModel] = [:]
    private let hydrationQueue = DispatchQueue(label: "yal.rooms.hydration", qos: .userInitiated)
    private var warmingInFlight = Set<String>()
    
    private let roomService: RoomServiceProtocol

    init(roomService: RoomServiceProtocol) {
        self.roomService = roomService
        self.didLoadRooms = Storage.get(for: .roomsLoadedFromNetwork, type: .userDefaults, as: Bool.self) ?? false
        self.didLoadMessages = Storage.get(for: .messagesLoadedFromNetwork, type: .userDefaults, as: Bool.self) ?? false
        
        roomService.hydrationProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hydrated, total in
                guard let self else { return }
                guard !self.didLoadRooms else {
                    self.hydrationHydrated = hydrated
                    self.hydrationTotal = total
                    self.isHydrating = false
                    self.hydrationProgress = 0
                    return
                }
                self.hydrationHydrated = hydrated
                self.hydrationTotal = total
                if total > 0 {
                    self.hydrationProgress = CGFloat(hydrated) / CGFloat(total)
                    self.isHydrating = hydrated < total
                } else {
                    self.hydrationProgress = 0
                    self.isHydrating = false
                }
            }
            .store(in: &cancellables)

        roomService.messageBackfillProgressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] done, total in
                guard let self else { return }
                guard !self.didLoadMessages else {
                    self.messageDownloadDone = done
                    self.messageDownloadTotal = total
                    self.isDownloadingMessages = false
                    self.messageDownloadProgress = 0
                    return
                }
                self.messageDownloadDone = done
                self.messageDownloadTotal = total
                if total > 0 {
                    self.messageDownloadProgress = CGFloat(done) / CGFloat(total)
                    self.isDownloadingMessages = done < total
                    if total == done {
                        self.roomService.startSync()
                        self.didLoadMessages = true
                        Storage.save(true, for: .messagesLoadedFromNetwork, type: .userDefaults)
                    }
                } else {
                    self.messageDownloadProgress = 0
                    self.isDownloadingMessages = false
                }
            }
            .store(in: &cancellables)
        
        if let profileModel = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            self.currentUser = ContactModel(
                phoneNumber: profileModel.mobile,
                userId: authSession.userId,
                fullName: profileModel.name
            )
        }
        
        roomService.roomsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                guard let self else { return }
                let copy = self.applyFlags(on: rooms)

                self.unFilteredRooms = copy
                self.lockedRooms     = copy.filter { $0.isLocked }
                self.blockedRooms    = copy.filter { $0.isBlocked }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3($unFilteredRooms, $searchText, $selectedFilter)
            .map { rooms, search, filter in
                var result = rooms.filter { !$0.isDeleted }
                switch filter {
                case .all: break
                case .unread:     result = result.filter { $0.unreadCount > 0 || !$0.isRead }
                case .chats:      result = result.filter { !$0.isGroup }
                case .groups:     result = result.filter { $0.isGroup }
                case .favourites: result = result.filter { $0.isFavorite }
                }
                if !search.isEmpty {
                    let lower = search.lowercased()
                    result = result.filter {
                        $0.name.lowercased().contains(lower) ||
                        $0.participants.contains(where: { $0.displayName?.lowercased().contains(lower) == true }) ||
                        $0.participants.contains(where: { $0.phoneNumber.lowercased().contains(lower) == true })
                    }
                }
                return result
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredRooms)
        
        roomService.typingPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                
            }, receiveValue: { [weak self] typingUpdate in
                self?.updateTypingIndicator(content: typingUpdate)
            })
            .store(in: &cancellables)
        
        roomService.inviteResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Sync error in RoomService: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] response in
                self?.invites = response
                self?.joinInvitedRooms()
            })
            .store(in: &cancellables)
    }
    
    func getLockedRooms() -> [RoomModel] {
        let lockedRoomIds = roomService.getLockedRooms()
        let temp = unFilteredRooms
        return temp.filter { room in
            return lockedRoomIds.contains(room.id)
        }
    }
    
    func getBlockedRooms() -> [RoomModel] {
        let blockedRoomIds = roomService.getBlockedRooms()
        let temp = unFilteredRooms
        return temp.filter { room in
            return blockedRoomIds.contains(room.id)
        }
    }

    func toggeleFavorite(for room: RoomModel) {
        roomService.toggleFavoriteRoom(roomID: room.id)
    }
    
    func toggeleDeleted(for room: RoomModel) {
        roomService.toggleDeletedRoom(roomID: room.id)
    }
    
    func toggeleMuted(for room: RoomModel) {
        roomService.toggleMutedRoom(roomID: room.id)
    }
    
    func toggeleLocked(for room: RoomModel) {
        roomService.toggleLockedRoom(roomID: room.id)
    }
    
    func toggeleRead(for room: RoomModel) {
        roomService.toggleMarkedAsUnreadRoom(roomID: room.id)
    }
    
    func toggeleBlocked(for room: RoomModel) {
        roomService.toggleBlockedRoom(roomID: room.id)
    }
    
    func refreshRoom(for room: RoomModel ) {
        room.isFavorite = roomService.getFavoriteRooms().contains(where: { $0.isEmpty ? false : $0 == room.id })
    }

    func restoreSession(accessToken: String) {
        roomService.restoreSession(accessToken: accessToken)
    }

    func loadRooms() {
        let snap = roomService.roomsSnapshot()
        let isFirstLaunch = !didLoadRooms && snap.isEmpty
        
        if !snap.isEmpty {
            // Fast paint from in-memory
            var fast = applyFlags(on: snap)
            DispatchQueue.main.async {
                self.unFilteredRooms = fast
                self.lockedRooms     = fast.filter { $0.isLocked }
                self.blockedRooms    = fast.filter { $0.isBlocked }
                self.roomService.startSync()
            }
        } else {
            // No in-memory snapshot → stream cached rooms in batches (delta append)
            if isFirstLaunch {
                LoaderManager.shared.show()
                isHydrating = true
                
                roomService.fetchAndPopulateRooms(onlyCache: didLoadRooms)
                    .sink(
                        receiveCompletion: { [weak self] _ in
                            guard let self else { return }
                            if isFirstLaunch && self.unFilteredRooms.isEmpty {
                                // truly zero rooms
                                LoaderManager.shared.hide()
                                DispatchQueue.main.async {
                                    self.isHydrating = false
                                }
                                self.didLoadRooms = true
                                Storage.save(true, for: .roomsLoadedFromNetwork, type: .userDefaults)
                            }
                            if self.didLoadRooms { self.roomService.startSync() }
                        },
                        receiveValue: { [weak self] event in
                            guard let self else { return }
                            switch event {
                            case let .started(_, _, allIds):
                                if isFirstLaunch { self.roomService.setExpectedRoomsIds(allIds) }
                                
                            case let .succeeded(_, index, allIds):
                                let total = allIds.count
                                if total > 0, index == total {
                                    var copy = self.applyFlags(on: self.unFilteredRooms)
                                    DispatchQueue.main.async {
                                        self.unFilteredRooms = copy
                                        self.lockedRooms     = copy.filter { $0.isLocked }
                                        self.blockedRooms    = copy.filter { $0.isBlocked }
                                        
                                        if isFirstLaunch {
                                            LoaderManager.shared.hide()
                                            self.isHydrating = false
                                        }
                                        self.didLoadRooms = true
                                        Storage.save(true, for: .roomsLoadedFromNetwork, type: .userDefaults)
                                    }
                                }
                                
                            case let .failed(_, index, allIds, _):
                                if index == allIds.count && isFirstLaunch {
                                    LoaderManager.shared.hide()
                                    self.isHydrating = false
                                }
                            }
                        }
                    )
                    .store(in: &cancellables)
            } else {
                roomService.loadCacheAndHydrateRoomsNow(includeContacts: true)
                self.roomService.startSync()
            }
        }
    }
    
    private func recomputeFilteredRooms() {
        var result = unFilteredRooms.filter { !$0.isDeleted }

        switch selectedFilter {
        case .all: break
        case .unread:    result = result.filter { $0.unreadCount > 0 || !$0.isRead }
        case .chats:     result = result.filter { !$0.isGroup }
        case .groups:    result = result.filter { $0.isGroup }
        case .favourites:result = result.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(lower)
                || $0.participants.contains(where: { $0.displayName?.lowercased().contains(lower) == true })
                || $0.participants.contains(where: { $0.phoneNumber.lowercased().contains(lower) == true })
            }
        }

        filteredRooms = result
    }
    
    private func scheduleWarm(ids: [String]) {
        // Dedup per id across overlapping batches
        let toWarm = ids.filter { warmingInFlight.insert($0).inserted }
        guard !toWarm.isEmpty else { return }

        hydrationQueue.async { [weak self] in
            guard let self else { return }

            // Fetch full summaries in the SAME ORDER as 'toWarm'
            let fulls = DBManager.shared.fetchFullRoomSummaries(
                ids: toWarm,
                limit: toWarm.count,
                sortKey: "lastServerTimestamp",
                ascending: false,
                includeContacts: true,          // pull contacts during warm
                resolveContact: nil             // use DBManager fallback resolver
            )

            // Map for quick lookup but keep 'toWarm' order when materializing
            let byIdSummary = Dictionary(uniqueKeysWithValues: fulls.map { ($0.id, $0) })

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                for id in toWarm {
                    defer { self.warmingInFlight.remove(id) }

                    guard let summary = byIdSummary[id] else { continue }

                    // Reuse the SAME instance already in the array if present
                    let existing = self.byId[id] ?? self.unFilteredRooms.first(where: { $0.id == id })

                    // This updates fields in place if 'existing' is provided
                    let hydrated = summary.materializeRoomModel(existing: existing)

                    // If materializer returned a different instance, replace in arrays+map
                    if let existing, hydrated !== existing {
                        if let idx = self.unFilteredRooms.firstIndex(where: { $0.id == id }) {
                            self.unFilteredRooms[idx] = hydrated
                        }
                    } else if existing == nil {
                        // (rare) if not present yet, insert sorted
                        self.insertSorted(&self.unFilteredRooms, hydrated) {
                            (($0.lastServerTimestamp ?? 0) > ($1.lastServerTimestamp ?? 0))
                        }
                    }

                    self.byId[id] = hydrated
                }

                // Recompute derived lists after warm (flags are unchanged)
                self.lockedRooms  = self.unFilteredRooms.filter { $0.isLocked }
                self.blockedRooms = self.unFilteredRooms.filter { $0.isBlocked }
            }
        }
    }
    
    func refreshRoomState(for room: RoomModel) {
        roomService.fetchAndUpdateRoomState(room: room)
    }
    
    // For all rooms
    func refreshAllRoomsState() {
        roomService.fetchAndUpdateAllRoomsState(rooms: filteredRooms)
    }
    
    func reloadRooms() {
        loadRooms()
    }

    func startChat(with userId: String, currentUserId: String, completion: @escaping (RoomModel?) -> Void) {
        if let roomModel = findExistingDirectRoom(with: userId) {
            completion(roomModel)
        } else {
            createRoom(currentUser: currentUserId, users: [userId], roomName: nil, roomDisplayImageUrl: nil, completion: completion)
        }
    }

    func createRoom(currentUser: String, users: [String], roomName: String?, roomDisplayImageUrl: String?, completion: @escaping (RoomModel?) -> Void) {
        LoaderManager.shared.show()
        roomService.createAndFetchRoomModel(currentUser: currentUser, invitees: users, roomName: roomName, roomDisplayImageUrl: roomDisplayImageUrl)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completionStatus in
                LoaderManager.shared.hide()
                if case .failure(let error) = completionStatus {
                    print("Error creating room: \(error.localizedDescription)")
                    completion(nil)
                }
            }, receiveValue: { roomModel in
                completion(roomModel)
            })
            .store(in: &cancellables)
    }

    func findExistingDirectRoom(with userId: String) -> RoomModel? {
        return unFilteredRooms.first(where: { room in
            !room.isGroup &&
            room.participants.count == 2 &&
            room.participants.contains(where: { $0.userId == userId })
        })
    }

    private func joinInvitedRooms() {
        for roomId in invites {
            joinRoom(roomId: roomId)
        }
    }

    private func joinRoom(roomId: String) {
        roomService.joinAndFetchRoomModel(roomId: roomId)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to join room \(roomId): \(error.localizedDescription)")
                }
            }, receiveValue: { response in
                if let roomModel = response {
                    print("Joined and fetched room \(roomModel.id)")
                }
            })
            .store(in: &cancellables)
    }

    func removeAllRooms() {
        for room in filteredRooms {
            roomService.leaveRoom(roomId: room.id)
                .sink(receiveCompletion: { [weak self] result in
                    switch result {
                    case .finished:
                        print("Successfully left room: \(room.id)")
                        self?.roomService.forgetRoom(roomId: room.id)
                        print("Room \(room.id) has been forgotten.")
                    case .failure(let error):
                        print("Failed to leave room: \(room.id), Error: \(error.localizedDescription)")
                    }
                }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
        print("Attempting to remove all rooms...")
    }
    
    private func updateTypingIndicator(content: TypingUpdate) {
        let roomId = content.roomId
        let currentUserId = currentUser?.userId
        
        // Exclude self from typing
        let typingIds = content.userIds.filter { $0 != currentUserId }
        // Get matched contacts for first name or phone
        let matchedUsers: [String] = filteredRooms
            .first(where: { $0.id == roomId })?
            .participants
            .filter { typingIds.contains($0.userId ?? "") }
            .compactMap {
                if let name = $0.fullName, !name.isEmpty {
                    return name.components(separatedBy: " ").first ?? name
                } else {
                    $0.phoneNumber
                }
                return nil
            } ?? []
        
        let indicator = typingIndicator(from: matchedUsers)
        typingIndicators[roomId] = indicator
    }
    
    private func typingIndicator(from names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return "\(names[0]) is typing..."
        case 2: return "\(names[0]) and \(names[1]) are typing..."
        default: return "\(names[0]), \(names[1]) and others are typing..."
        }
    }
}

extension RoomListViewModel {
    /// Deletes the room and its messages locally (Realm only, no server call)
    func clearChatAndDeleteRoomLocally(roomId: String) {
        // add here logic foer delete locally
        filteredRooms.removeAll { $0.id == roomId }
    }
}

extension RoomListViewModel {
    
    /// Mutes the notifications for a room
    func muteRoomNotifications(for room: RoomModel, duration: MuteDuration, completion: ((Bool) -> Void)? = nil) {
        roomService.muteRoomNotifications(roomId: room.id, duration: duration)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("Network error muting room notifications: \(error.localizedDescription)")
                    completion?(false)
                }
            }, receiveValue: { response in
                switch response {
                case .success:
                    print("Successfully muted notifications for room \(room.id)")
                    completion?(true)
                case .unsuccess(let error):
                    print("Mute API returned error: \(error.localizedDescription)")
                    completion?(false)
                }
            })
            .store(in: &cancellables)
    }
    
    /// Unmutes the notifications for a room
    func unmuteRoomNotifications(for room: RoomModel, completion: ((Bool) -> Void)? = nil) {
        roomService.unmuteRoomNotifications(roomId: room.id)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("Network error unmuting room notifications: \(error.localizedDescription)")
                    completion?(false)
                }
            }, receiveValue: { response in
                switch response {
                case .success:
                    print("Successfully unmuted notifications for room \(room.id)")
                    completion?(true)
                case .unsuccess(let error):
                    print("Unmute API returned error: \(error.localizedDescription)")
                    completion?(false)
                }
            })
            .store(in: &cancellables)
    }
    
    /// Unbans a user from a room
    func unbanUser(from room: RoomModel, user: ContactModel, completion: ((Bool) -> Void)? = nil) {
        guard let userId = user.userId else {
            completion?(false)
            return
        }

        roomService.unbanFromRoom(roomId: room.id, userId: userId)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("Network error unbanning user: \(error.localizedDescription)")
                    completion?(false)
                }
            }, receiveValue: { response in
                switch response {
                case .success:
                    print("Successfully unbanned user \(userId) from room \(room.id)")
                    completion?(true)
                case .unsuccess(let error):
                    print("Unban API returned error: \(error.localizedDescription)")
                    completion?(false)
                }
            })
            .store(in: &cancellables)
    }
    
    /// Bans a user from a room
    func banUser(from room: RoomModel, user: ContactModel, reason: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let userId = user.userId else {
            completion?(false)
            return
        }
        roomService.banFromRoom(roomId: room.id, userId: userId, reason: reason)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("Network error banning user: \(error.localizedDescription)")
                    completion?(false)
                }
            }, receiveValue: { response in
                switch response {
                case .success:
                    print("Successfully banned user \(userId) from room \(room.id)")
                    completion?(true)
                case .unsuccess(let error):
                    print("Ban API returned error: \(error.localizedDescription)")
                    completion?(false)
                }
            })
            .store(in: &cancellables)
    }

    func clearChat(roomId: String) {
        DBManager.shared.deleteMessages(inRoom: roomId)
        print("Chat cleared for room: \(roomId)")
    }
}

private extension RoomListViewModel {
    // Apply persisted flags to the provided rooms (mutates in place)
    func applyFlags(on rooms: [RoomModel]) -> [RoomModel] {
        let favoriteIDs = Set(roomService.getFavoriteRooms())
        let deletedIDs  = Set(roomService.getDeletedRooms())
        let mutedIDs    = Set(roomService.getMutedRooms())
        let unreadIDs   = Set(roomService.getUnreadRooms())
        let blockedIDs  = Set(roomService.getBlockedRooms())
        let lockedIDs   = Set(roomService.getLockedRooms())
        
        let out = rooms
        for i in out.indices {
            let id = out[i].id
            DispatchQueue.main.async {
                out[i].isFavorite = favoriteIDs.contains(id)
                out[i].isDeleted  = deletedIDs.contains(id)
                out[i].isMuted    = mutedIDs.contains(id)
                out[i].isRead     = !unreadIDs.contains(id)
                out[i].isBlocked  = blockedIDs.contains(id)
                out[i].isLocked   = lockedIDs.contains(id)
            }
        }
        return out
    }


    @inline(__always)
    func insertSorted<T>(_ array: inout [T], _ element: T, by areInDecreasingOrder: (T, T) -> Bool) {
        var low = 0, high = array.count
        while low < high {
            let mid = (low + high) / 2
            if areInDecreasingOrder(array[mid], element) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        array.insert(element, at: low)
    }
}
        
extension RoomListViewModel {
    
    /// Returns the direct chat room with a specific contact (if exists)
    func getDirectRoomModel(for contact: ContactModel) -> RoomModel? {
        guard let userId = contact.userId else { return nil }
        
        return unFilteredRooms.first(where: { room in
            !room.isGroup &&
            room.participants.count == 2 &&
            room.participants.contains(where: { $0.userId == userId })
        })
    }
}

