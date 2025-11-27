//
//  ChatViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import Combine
import AVFoundation

final class ChatViewModel: ObservableObject {
    // MARK: - Deps & State
    private let roomService: RoomServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var newMessage: String = ""
    @Published var currentUser: ContactModel?
    @Published var messages: [ChatMessageModel] = []
    @Published var typingUsers: [ContactModel] = []
    @Published var showNotAMemberBar: Bool = false
    @Published var firstMessageEventId: String?
    private var allMessages: [ChatMessageModel] = []
    private var oldMessagesPageSize: Int = 10
    
    let audioPlayer = AudioPlayer()

    @Published var selectedMessagesToForword: [ChatMessageModel] = []
    @Published var sharedMediaPayload: [ChatMessageModel]?
    @Published private(set) var isPagingTop = false
    private var canLoadMoreTop = true

    var currentRoomId: String?
    var selectedRoom: RoomModel?

    // Single worker for all heavy work
    private let processQ = DispatchQueue(label: "chat.vm.process", qos: .userInitiated)

    @Published private(set) var sections: [MessageSection] = []

    private func buildSections(from messages: [ChatMessageModel]) -> [MessageSection] {
        @inline(__always) func startOfDay(_ d: Date) -> Date {
            Calendar.current.startOfDay(for: d)
        }
        let dict = Dictionary(grouping: messages) { msg in
            startOfDay(Date(timeIntervalSince1970: TimeInterval(msg.timestamp) / 1000))
        }
        let keys = dict.keys.sorted()
        return keys.map { day in
            let items = (dict[day] ?? []).sorted { $0.timestamp < $1.timestamp }
            let title: String = {
                if Calendar.current.isDateInToday(day) { return "Today" }
                if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                return fmt.string(from: day)
            }()
            return MessageSection(date: day, title: title, messages: items)
        }
    }
    
    // MARK: - Init
    init(roomService: RoomServiceProtocol) {
        self.roomService = roomService

        if let profileModel = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            self.currentUser = ContactModel(
                phoneNumber: profileModel.mobile,
                userId: authSession.userId,
                fullName: profileModel.name
            )
        }

        // Redactions — cheap transform, but still avoid main until mutate UI.
        roomService.redactionPublisher
            .subscribe(on: processQ)
            .receive(on: processQ)
            .sink { [weak self] eventId in
                self?.applyRedaction(eventId: eventId)
            }
            .store(in: &cancellables)

        // Incoming messages — merge off-main, then publish once on main
        roomService.chatMessagesPublisher
            .subscribe(on: processQ)
            .receive(on: processQ)
            .map { [weak self] incoming -> [ChatMessageModel] in
                guard let self else { return [] }
                let mergedMessages = self.mergedMessages(
                    current: self.allMessages,
                    incoming: incoming,
                    currentRoomId: self.currentRoomId
                )
                self.allMessages = mergedMessages
                return mergedMessages
            }
            .sink(receiveValue: { [weak self] merged in
                //print("Merged messsages: \(merged.count)")
                guard let self else { return }
                let sections = self.buildSections(from: merged) // off-main safe
                DispatchQueue.main.async {
                    if self.messages.isEmpty {
                        self.firstMessageEventId = merged.first?.eventId
                    } else if self.messages.count % 10 == 0 {
                        self.firstMessageEventId = self.messages.first?.eventId
                    }
                    self.messages = merged
                    self.sections = sections
                }
            })
            .store(in: &cancellables)

        // Ephemeral (receipts) — compute target index off-main, mutate UI on main
        roomService.ephemeralPublisher
            .subscribe(on: processQ)
            .receive(on: DispatchQueue.main)
            .compactMap { [weak self] update -> (Int, [MessageReadReceipt])? in
                guard let self else { return nil }
                guard let idx = self.messages.firstIndex(where: { $0.eventId == update.eventId }) else { return nil }
                return (idx, update.receipts)
            }
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                if case let .failure(error) = completion {
                    DispatchQueue.main.async { self.errorMessage = "Failed to update ephemeral messages: \(error.localizedDescription)" }
                }
            }, receiveValue: { [weak self] idx, receipts in
                DispatchQueue.main.async {
                    if let messages = self?.messages, messages.count > idx {
                        self?.messages[idx].receipts = receipts
                    }
                }
            })
            .store(in: &cancellables)

        // Typing — filter / map / dedupe / throttle off-main, then set on main
        roomService.typingPublisher
            .subscribe(on: processQ)
            .receive(on: processQ)
            .filter { [weak self] update in
                update.roomId == self?.currentRoomId
            }
            .map { [weak self] update -> [ContactModel] in
                guard let self else { return [] }
                let me = self.currentUser?.userId
                let ids = update.userIds.filter { $0 != me }
                return self.selectedRoom?.participants.filter {
                    if let uid = $0.userId {
                        return ids.contains(uid)
                    } else {
                        return false
                    }
                } ?? []
            }
            .removeDuplicates(by: { lhs, rhs in
                // Safely unwrap and compare non-optional userIds
                let leftIds = lhs.compactMap { $0.userId }.sorted()
                let rightIds = rhs.compactMap { $0.userId }.sorted()
                return leftIds == rightIds
            })
            .throttle(for: .milliseconds(300), scheduler: processQ, latest: true)
            .sink { [weak self] users in
                DispatchQueue.main.async {
                    self?.typingUsers = users
                }
            }
            .store(in: &cancellables)

        // Input-driven typing indicator — debounce on main is fine; send off-main
        $newMessage
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self,
                      let currentUserId = self.currentUser?.userId,
                      let roomId = self.currentRoomId else { return }
                self.sendTyping(roomId: roomId, userId: currentUserId, typing: true)
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    func sendMessageWithURLPreview(toRoom roomId: String, inReplyTo: ChatMessageModel? = nil) {
            // Extract URLs
            let urls = URLDetector.extractURLs(from: newMessage)
            
            if let firstURL = urls.first {
                // Send message immediately
                sendMessage(toRoom: roomId, inReplyTo: inReplyTo)
                
                // Fetch preview in background
                Task {
                    let fetcher = URLPreviewFetcher()
                    await fetcher.fetchPreview(for: firstURL)
                    
                    if let preview = fetcher.previewData {
                        // Store in cache for future use
                        URLPreviewCache.shared.setPreview(preview, for: firstURL)
                    }
                }
            } else {
                sendMessage(toRoom: roomId, inReplyTo: inReplyTo)
            }
        }
    func switchRoom(to roomId: String) {
        guard currentRoomId != roomId else { return }

        disableMessageObservation()

        processQ.async { [weak self] in
            self?.allMessages.removeAll()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.messages.removeAll()
            self.sections.removeAll()
            self.firstMessageEventId = nil
            self.typingUsers.removeAll()
            self.isPagingTop = false
            self.canLoadMoreTop = true
            self.errorMessage = nil
            self.isLoading = true
        }

        currentRoomId = roomId

        enableMessageObservation()
        fetchMessages(forRoom: roomId)
    }
    
    func enableMessageObservation() {
        if let currentRoomId = currentRoomId {
            roomService.enableMessageObservation(for: currentRoomId)
        }
    }

    func disableMessageObservation() {
        roomService.disableMessageObservation()
    }
    
    // MARK: - Helpers (off-main safe)
    private func mergedMessages(
        current: [ChatMessageModel],
                                incoming: [ChatMessageModel],
                                currentRoomId: String?
    ) -> [ChatMessageModel] {
        guard let currentRoomId else { return current }
        var map: [String: ChatMessageModel] = Dictionary(uniqueKeysWithValues: current.map { ($0.eventId, $0) })

        for msg in incoming where msg.roomId == currentRoomId {
            if let existing = map[msg.eventId] {
                if let newUrl = msg.mediaUrl, !newUrl.isEmpty, newUrl != existing.mediaUrl {
                    existing.mediaUrl = newUrl
                }
                if let newInfo = msg.mediaInfo, newInfo != existing.mediaInfo {
                    existing.mediaInfo = newInfo
                }
                if msg.downloadState != .notStarted, msg.downloadState != existing.downloadState {
                    existing.downloadState = msg.downloadState
                }
                if msg.downloadProgress > 0, msg.downloadProgress != existing.downloadProgress {
                    existing.downloadProgress = msg.downloadProgress
                }
                for r in msg.reactions {
                    if let i = existing.reactions.firstIndex(where: { $0.userId == r.userId }) {
                        if existing.reactions[i].key != r.key || existing.reactions[i].timestamp != r.timestamp {
                            existing.reactions[i].key = r.key
                            existing.reactions[i].timestamp = r.timestamp
                        }
                    } else {
                        existing.reactions.append(r)
                    }
                }
            } else {
                map[msg.eventId] = msg
            }
        }
        let merged = Array(map.values)
        return merged.sorted { $0.timestamp < $1.timestamp }
    }

    private func applyRedaction(eventId: String) {
        guard let idx = messages.firstIndex(where: { $0.eventId == eventId }) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.messages[idx].isRedacted = true
            self.messages[idx].content = thisMessageWasDeleted
        }
    }

    // MARK: - Public API (unchanged signatures)

    func sharedMedia() {
        // cheap filter
        sharedMediaPayload = messages.filter { $0.mediaUrl != nil }
    }

    func toggleMessageSelection() {
        selectedMessagesToForword = messages.filter { $0.isSelected }
    }

    func clearChat(roomId: String) {
        processQ.async {
            DBManager.shared.deleteMessages(inRoom: roomId)
        }
        DispatchQueue.main.async { [weak self] in
            self?.messages.removeAll()
        }
    }

    func getblockedUsers() -> [String] {
        roomService.getBlockedRooms()
    }

    func toggleBlockUser(currentRoomId: String) {
        _ = roomService.toggleBlockedRoom(roomID: currentRoomId)
    }

    func banUser(userId: String, currentRoomId: String) {
        _ = roomService.banFromRoom(roomId: currentRoomId, userId: userId, reason: "")
    }

    func unbanUser(userId: String, currentRoomId: String) {
        _ = roomService.unbanFromRoom(roomId: currentRoomId, userId: userId)
    }

    func fetchMessages(forRoom roomId: String) {
        DispatchQueue.main.async { self.isLoading = true; self.currentRoomId = roomId }
        roomService.getMessages(forRoom: roomId)
    }

    func updateMessages(incoming: [ChatMessageModel]) {
        // Kept for compatibility (if something else calls it), but do the work off-main.
        processQ.async { [weak self] in
            guard let self else { return }
            let merged = self.mergedMessages(current: self.messages, incoming: incoming, currentRoomId: self.currentRoomId)
            DispatchQueue.main.async { self.messages = merged }
        }
    }

    private func updateReceipts(content: ReceiptUpdate) {
        // Kept for compatibility when called from old sink
        processQ.async { [weak self] in
            guard let self else { return }
            guard let idx = self.messages.firstIndex(where: { $0.eventId == content.eventId }) else { return }
            DispatchQueue.main.async {
                self.messages[idx].receipts = content.receipts
            }
        }
    }

    private func updateTypingIndicator(content: TypingUpdate) {
        // Kept for compatibility when called from old sink
        processQ.async { [weak self] in
            guard let self else { return }
            guard content.roomId == self.currentRoomId else { return }
            let me = self.currentUser?.userId
            let typingIds = content.userIds.filter { $0 != me }
            let matched = self.selectedRoom?.participants.filter { typingIds.contains($0.userId ?? "") } ?? []
            DispatchQueue.main.async { self.typingUsers = matched }
        }
    }

    func sendMessage(toRoom roomId: String, inReplyTo: ChatMessageModel? = nil) {
        // Extract URLs
        let urls = URLDetector.extractURLs(from: newMessage)
        
        // Your existing send logic
        guard !newMessage.isEmpty,
              let userId = currentUser?.userId,
              let currentRoomId = currentRoomId else { return }
        
        // ... rest of your existing code ...
        
        // After sending, fetch preview in background
        if let firstURL = urls.first {
            Task {
                let fetcher = URLPreviewFetcher()
                await fetcher.fetchPreview(for: firstURL)
                
                if let preview = fetcher.previewData {
                    URLPreviewCache.shared.setPreview(preview, for: firstURL)
                }
            }
        }
        
        newMessage = ""
    }
    func markMessageAsRead(roomId: String, eventId: String, usePrivate: Bool = false) {
        roomService.sendReadMarker(
            roomId: roomId,
            fullyReadEventId: eventId,
            readEventId: eventId,
            readPrivateEventId: usePrivate ? eventId : nil
        )
        .subscribe(on: processQ)
        .receive(on: processQ)
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Failed to send read marker: \(error)")
            }
        }, receiveValue: { [weak self] _ in
            self?.roomService.updateMessageStatus(eventId: eventId, status: .read)
        })
        .store(in: &cancellables)
    }

    func fetchMedia(for message: ChatMessageModel) {
        guard
            let mxcUrl = message.mediaUrl,
            let (_, mediaId) = parseMXC(mxc: mxcUrl)
        else { return }

        let fileName = mediaId + "." + fileExtensionForMimeType(mimeType: message.mediaInfo?.mimetype ?? "image/jpeg")
        let targetId = message.eventId

        // Capture an index once (fast path). We'll verify before using.
        let initialIndex = messages.firstIndex { $0.eventId == targetId }

        // Set state once (guarding bounds)
        DispatchQueue.main.async {
            if let i = initialIndex, self.messages.indices.contains(i), self.messages[i].eventId == targetId {
                self.messages[i].downloadState = .downloading
            } else if let j = self.messages.firstIndex(where: { $0.eventId == targetId }) {
                self.messages[j].downloadState = .downloading
            }
        }

        // Lightweight throttling: max ~12 fps OR >=2% delta OR endpoints (0/1)
        var lastEmit = CFAbsoluteTimeGetCurrent()
        var lastValue: Double = -1.0

        roomService.downloadMediaForMessage(
            mxcUrl: mxcUrl,
            fileName: fileName,
            onProgress: { [weak self] p in
                guard let self else { return }
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastEmit < 0.08, abs(p - lastValue) < 0.02, p > 0.0, p < 1.0 { return }
                lastEmit = now
                lastValue = p

                DispatchQueue.main.async {
                    // Prefer captured index; fall back if list moved
                    if let i = initialIndex,
                       self.messages.indices.contains(i),
                       self.messages[i].eventId == targetId {
                        self.messages[i].downloadProgress = p
                    } else if let j = self.messages.firstIndex(where: { $0.eventId == targetId }) {
                        self.messages[j].downloadProgress = p
                    }
                }
            }
        )
        .subscribe(on: processQ)
        .receive(on: processQ)
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                func setState(_ state: MediaDownloadState) {
                    if let i = initialIndex,
                       self.messages.indices.contains(i),
                       self.messages[i].eventId == targetId {
                        self.messages[i].downloadState = state
                    } else if let j = self.messages.firstIndex(where: { $0.eventId == targetId }) {
                        self.messages[j].downloadState = state
                    }
                }

                switch result {
                case .success:
                    setState(.downloaded)
                case .unsuccess(let e):
                    self.errorMessage = e.localizedDescription
                    setState(.failed)
                }
            }
        })
        .store(in: &cancellables)
    }

    func sendMediaMessage(
        message: ChatMessageModel,
        roomId: String,
        messageType: String,
        localURL: String? = nil,
        mediaURL: String? = nil,
        thumbnailURL: String? = nil,
        fileName: String,
        mimeType: String,
        duration: Double? = nil,
        size: Int64? = nil,
        completion: @escaping (_ sendMessageResponse: SendMessageResponse) -> Void
    ) {
        getMediaDimensions(mediaType: messageType, localURL: localURL) { [weak self] width, height in
            guard let self else { return }

            let mediaInfo = MediaInfo(
                thumbnailUrl: thumbnailURL,
                thumbnailInfo: nil,
                w: width, h: height,
                duration: Int(duration ?? 0),
                size: Int(size ?? 0),
                mimetype: mimeType
            )

            let temp = message
            temp.mediaUrl = mediaURL
            temp.mediaInfo = mediaInfo
            temp.downloadProgress = 0.0
            temp.downloadState = .notStarted

            self.roomService.sendMessage(message: temp)
                .subscribe(on: self.processQ)
                .receive(on: self.processQ)
                .sink(receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        print("[sendMediaMessage] Failed: \(error.localizedDescription)")
                    }
                }, receiveValue: { result in
                    switch result {
                    case .success(let resp):
                        DispatchQueue.main.async { completion(resp) }
                    case .unsuccess(let e):
                        print("[sendMediaMessage] API Error: \(e.localizedDescription)")
                    }
                })
                .store(in: &self.cancellables)
        }
    }

    func uploadAndSendMediaMessage(fileURL: URL,
                                   fileName: String,
                                   mimeType: String,
                                   duration: Double? = nil,
                                   size: Int64? = nil,
                                   localPreview: UIImage? = nil) {
        guard let roomId = selectedRoom?.id,
              let userId = currentUser?.userId else { return }

        let tempId = UUID().uuidString
        let ts = Int64(Date().timeIntervalSince1970 * 1000)

        let temp = ChatMessageModel(
            eventId: tempId, sender: userId, content: "",
            timestamp: ts, msgType: messageType(for: mimeType).rawValue,
            mediaUrl: nil, mediaInfo: nil, userId: userId, roomId: roomId,
            receipts: [], downloadState: .downloading, downloadProgress: 0.1, messageStatus: .sending
        )
        temp.localPreviewImage = localPreview
        DispatchQueue.main.async { self.messages.append(temp) }

        roomService.uploadMedia(fileURL: fileURL, fileName: fileName, mimeType: mimeType, onProgress: { [weak self] p in
            guard let self else { return }
            // Coalesce on a serial queue
            self.processQ.async { [weak self] in
                var lastTick = CFAbsoluteTimeGetCurrent()
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastTick > (1.0 / 15.0) { // ~15fps
                    lastTick = now
                    DispatchQueue.main.async {
                        if let i = self?.messages.firstIndex(where: { $0.eventId == tempId }) {
                            self?.messages[i].downloadProgress = p
                        }
                    }
                }
            }
        })
        .subscribe(on: processQ)
        .receive(on: processQ)
        .sink(receiveCompletion: { [weak self] completion in
            guard let self else { return }
            if case .failure(let e) = completion {
                print("[upload] failed: \(e.localizedDescription)")
                DispatchQueue.main.async {
                    if let i = self.messages.firstIndex(where: { $0.eventId == tempId }) {
                        self.messages[i].downloadState = .failed
                    }
                }
            }
        }, receiveValue: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let mediaURL):
                self.sendMediaMessage(
                    message: temp, roomId: roomId,
                    messageType: messageType(for: mimeType).rawValue,
                    mediaURL: mediaURL.absoluteString,
                    fileName: fileName, mimeType: mimeType
                ) { resp in
                    DispatchQueue.main.async {
                        if let i = self.messages.firstIndex(where: { $0.eventId == tempId }) {
                            self.messages[i].eventId = resp.eventId
                            self.messages[i].mediaUrl = mediaURL.absoluteString
                            self.messages[i].downloadState = .downloaded
                            self.messages[i].messageStatus = .sent
                        }
                    }
                }
            case .unsuccess(let e):
                print("[upload] API error: \(e.localizedDescription)")
                DispatchQueue.main.async {
                    if let i = self.messages.firstIndex(where: { $0.eventId == tempId }) {
                        self.messages[i].downloadState = .failed
                    }
                }
            }
        })
        .store(in: &cancellables)
    }

    func uploadUserProfile(
        fileURL: URL,
        fileName: String,
        mimeType: String,
        completion: @escaping (_ success: Bool, _ url: URL?) -> Void
    ) {
        roomService.uploadMedia(fileURL: fileURL, fileName: fileName, mimeType: mimeType, onProgress: { _ in })
            .subscribe(on: processQ)
            .receive(on: processQ)
            .sink(receiveCompletion: { status in
                if case .failure(let e) = status {
                    print("[uploadUserProfile] failed: \(e.localizedDescription)")
                    DispatchQueue.main.async { completion(false, nil) }
                }
            }, receiveValue: { result in
                switch result {
                case .success(let url):
                    DispatchQueue.main.async { completion(true, url) }
                case .unsuccess(let e):
                    print("[uploadUserProfile] API error: \(e.localizedDescription)")
                    DispatchQueue.main.async { completion(false, nil) }
                }
            })
            .store(in: &cancellables)
    }
        
    func uploadGroupProfile(fileURL: URL,
                            fileName: String,
                            mimeType: String,
                            duration: Double? = nil,
                            size: Int64? = nil,
                            completion: @escaping (_ url: URL?) -> Void) {
        LoaderManager.shared.show()
        roomService.uploadMedia(fileURL: fileURL, fileName: fileName, mimeType: mimeType, onProgress: { _ in })
            .subscribe(on: processQ)
            .receive(on: processQ)
            .sink(receiveCompletion: { status in
                LoaderManager.shared.hide()
                if case .failure(let e) = status {
                    print("[uploadGroupProfile] failed: \(e.localizedDescription)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }, receiveValue: { result in
                switch result {
                case .success(let url):
                    DispatchQueue.main.async { completion(url) }
                case .unsuccess(let e):
                    print("[uploadGroupProfile] API error: \(e.localizedDescription)")
                    DispatchQueue.main.async { completion(nil) }
                }
            })
            .store(in: &cancellables)
    }

    func sendTyping(roomId: String, userId: String, typing: Bool) {
        roomService.sendTyping(roomId: roomId, userId: userId, typing: typing)
            .subscribe(on: processQ)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func deleteMessage(roomId: String, eventId: String, reason: String? = nil) {
        roomService.deleteMessage(roomId: roomId, eventId: eventId, reason: reason)
            .subscribe(on: processQ)
            .receive(on: processQ)
            .sink(receiveCompletion: { [weak self] _ in
                DispatchQueue.main.async { self?.isLoading = false }
            }, receiveValue: { [weak self] response in
                guard let self else { return }
                switch response {
                case .success:
                    DispatchQueue.main.async {
                        if let idx = self.messages.firstIndex(where: { $0.eventId == eventId }) {
                            self.messages[idx].isRedacted = true
                            DBManager.shared.markMessageRedacted(eventId: eventId)
                        }
                    }
                case .unsuccess(let e):
                    print("Error deleting message: \(e.localizedDescription)")
                }
            })
            .store(in: &cancellables)
    }

    func sendReaction(to message: ChatMessageModel, emoji: Emoji) {
        let tempId = UUID().uuidString
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        let userId = message.currentUserId

        if let idx = message.reactions.firstIndex(where: { $0.userId == userId }) {
            roomService.updateReaction(message: message, emoji: emoji)
                .subscribe(on: processQ)
                .sink(receiveCompletion: { c in
                    if case .failure(let e) = c { print("Failed to update reaction: \(e)") }
                }, receiveValue: { result in
                    if case .success(let resp) = result,
                       let i = message.reactions.firstIndex(where: { $0.userId == userId }) {
                        message.reactions[i].eventId = resp.eventId
                    }
                })
                .store(in: &cancellables)

            message.reactions[idx].key = emoji.symbol
            message.reactions[idx].timestamp = ts

        } else {
            message.reactions.append(.init(eventId: tempId, userId: userId, key: emoji.symbol, timestamp: ts))
            roomService.sendReaction(to: message, emoji: emoji)
                .subscribe(on: processQ)
                .sink(receiveCompletion: { c in
                    if case .failure(let e) = c { print("Failed to send reaction: \(e)") }
                }, receiveValue: { result in
                    if case .success(let resp) = result,
                       let i = message.reactions.firstIndex(where: { $0.eventId == tempId }) {
                        message.reactions[i].eventId = resp.eventId
                    }
                })
                .store(in: &cancellables)
        }
    }

    func loadOlderIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard let roomId = currentRoomId,
              !isPagingTop,
              canLoadMoreTop else {
            completion?(false)
            return
        }

        isPagingTop = true

        roomService.fetchOlderMessages(roomId: roomId, pageSize: oldMessagesPageSize)
            .subscribe(on: processQ)
            .receive(on: processQ)
            .sink(receiveCompletion: { [weak self] c in
                DispatchQueue.main.async { self?.isPagingTop = false }
                if case .failure = c { DispatchQueue.main.async { completion?(false) } }
            }, receiveValue: { [weak self] hadNew in
                DispatchQueue.main.async {
                    if !hadNew { self?.canLoadMoreTop = false }
                    self?.isPagingTop = false
                    completion?(hadNew)
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - Local Deletes
extension ChatViewModel {
    func deleteLocalMessage(eventId: String) {
        processQ.async {
            DBManager.shared.deleteMessage(eventId: eventId)
        }
        DispatchQueue.main.async { [weak self] in
            if let i = self?.messages.firstIndex(where: { $0.eventId == eventId }) {
                self?.messages.remove(at: i)
            }
        }
    }
}
