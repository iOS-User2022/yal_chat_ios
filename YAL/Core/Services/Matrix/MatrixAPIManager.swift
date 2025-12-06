//
//  MatrixAPIManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import Foundation
import Combine

final class MatrixAPIManager: MatrixAPIManagerProtocol {
    static let shared: MatrixAPIManagerProtocol = MatrixAPIManager()
    
    private var client: HttpClientProtocol?
    private var accessToken: String?
    
    private var isWaitingForSyncResponse = false
    private var isWaitingForChatResponse = false

    private var syncTimer: DispatchSourceTimer?
    private var messageSyncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let syncQ = DispatchQueue(label: "yal.matrix.sync", qos: .userInitiated)
    private var messageTimer: DispatchSourceTimer?
    
    // Sync and scheduling parameters
    private var nextBatch: String?
    private var lastMessageEventId: String?
    
    // PassthroughSubject to publish sync responses
    private var syncResponseSubject = PassthroughSubject<APIResult<SyncResponse>, Never>()
    var syncResponsePublisher: AnyPublisher<APIResult<SyncResponse>, Never> {
        return syncResponseSubject.eraseToAnyPublisher()
    }
    
    // PassthroughSubject to publish chat messages
    private var chatMessagesSubject = PassthroughSubject<APIResult<GetMessagesResponse>, APIError>()
    var chatMessagesPublisher: AnyPublisher<APIResult<GetMessagesResponse>, APIError> {
        return chatMessagesSubject.eraseToAnyPublisher()
    }
    
    private init () {
        self.accessToken = nil
    }
    
    func injectHTTPClient(httpClient: HttpClientProtocol) {
        self.client = httpClient
        self.client?.isMatrixClient = true
    }
    
    func injectAccessToken(_ token: String) {
        self.accessToken = token
    }
    
    // MARK: - Authentication
    
    //    func login(username: String, password: String) -> AnyPublisher<APIResult<MatrixLoginResponse>, APIError> {
    //        let loginEndpoint = MatrixAPIEndpoints.login.urlString()
    //        let loginRequest = MatrixLoginRequest(type: "m.login.password", user: username, password: password)
    //        return performPost(loginEndpoint, loginRequest, expecting: MatrixLoginResponse.self)
    //    }
    
    //    func logout() -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
    //        guard let token = accessToken else {
    //            return Just(.unsuccess(.unauthorized))
    //                .setFailureType(to: APIError.self)
    //                .eraseToAnyPublisher()
    //        }
    //        let logoutEndpoint = MatrixAPIEndpoints.logout.urlString()
    //        return performPost(logoutEndpoint, EmptyRequest(), expecting: EmptyResponse.self)
    //    }
    
    // MARK: - Sending Messages
    
    func sendMessage(roomId: String, message: MessageRequest) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
      guard let _ = accessToken else {
        return Just(.unsuccess(.unauthorized))
          .setFailureType(to: APIError.self)
          .eraseToAnyPublisher()
      }

      let txnId = UUID().uuidString

      let endpoint = MatrixAPIEndpoints
        .sendMessage
        .urlString(
          withPathParameters: [
            "roomId": roomId,
            "eventType": "m.room.message",
            "txnId": txnId
          ]
        )

      return performPut(
        endpoint,
        message,
        expecting: SendMessageResponse.self
      )
    }
    
    // MARK: - Room Operations
    
    func createRoom(createRoomRequest: CreateRoomRequest) -> AnyPublisher<APIResult<CreateRoomResponse>, APIError> {
        let createRoomEndpoint = MatrixAPIEndpoints.createRoom.urlString()
        return performPost(createRoomEndpoint, createRoomRequest, expecting: CreateRoomResponse.self)
    }
    
    func getJoinedRooms() -> AnyPublisher<APIResult<JoinedRooms>, APIError> {
        let joinRoomEndpoint = MatrixAPIEndpoints.joinedRooms.urlString()
        return performGet(joinRoomEndpoint, expecting: JoinedRooms.self)
    }
    
    func joinRoom(roomId: String) -> AnyPublisher<APIResult<JoinRoomResponse>, APIError> {
        let joinRoomEndpoint = MatrixAPIEndpoints.joinRoom.urlString(withPathParameters: ["roomId": roomId])
        return performPost(joinRoomEndpoint, MatrixEmptyRequest(), expecting: JoinRoomResponse.self)
    }
    
    func leaveRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let leaveRoomEndpoint = MatrixAPIEndpoints.leaveRoom.urlString(withPathParameters: ["roomId": roomId])
        return performPost(leaveRoomEndpoint, MatrixEmptyRequest(), expecting: MatrixEmptyResponse.self)
    }
    
    func forgetRoom(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let forgetRoomEndpoint = MatrixAPIEndpoints.forgetRoom.urlString(withPathParameters: ["roomId": roomId])
        return performPost(forgetRoomEndpoint, MatrixEmptyRequest(), expecting: MatrixEmptyResponse.self)
    }
    
    func inviteToRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let inviteRoomEndpoint = MatrixAPIEndpoints.inviteToRoom.urlString(withPathParameters: ["roomId": roomId])
        let inviteRequest = InviteRoomRequest(userId: userId)
        return performPost(inviteRoomEndpoint, inviteRequest, expecting: MatrixEmptyResponse.self)
    }
    
    func kickFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let kickRoomEndpoint = MatrixAPIEndpoints.kickFromRoom.urlString(withPathParameters: ["roomId": roomId])
        let kickRequest = KickRoomRequest(userId: userId)
        return performPost(kickRoomEndpoint, kickRequest, expecting: MatrixEmptyResponse.self)
    }
    
    func banFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let banRoomEndpoint = MatrixAPIEndpoints.banFromRoom.urlString(withPathParameters: ["roomId": roomId])
        let banRequest = BanRoomRequest(userId: userId)
        return performPost(banRoomEndpoint, banRequest, expecting: MatrixEmptyResponse.self)
    }
    
    func unbanFromRoom(roomId: String, userId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let unbanEndpoint = MatrixAPIEndpoints.unbanFromRoom.urlString(withPathParameters: ["roomId": roomId])
        let unbanRequest = BanRoomRequest(userId: userId)
        return performPost(unbanEndpoint, unbanRequest, expecting: MatrixEmptyResponse.self)
    }

    func muteRoomNotifications(roomId: String, duration: MuteDuration) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let muteEndpoint = MatrixAPIEndpoints.roomPushRule.urlString(withPathParameters: ["roomId": roomId])
        let pushRuleRequest = PushRuleActionsRequest(actions: ["dont_notify"])
        return performPut(muteEndpoint, pushRuleRequest, expecting: MatrixEmptyResponse.self)
    }
    
    func unmuteRoomNotifications(roomId: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let unmuteEndpoint = MatrixAPIEndpoints.roomPushRule.urlString(withPathParameters: ["roomId": roomId])
        return performDelete(unmuteEndpoint, body: MatrixEmptyRequest(), expecting: MatrixEmptyResponse.self)
    }
    
    // MARK: - User Profile
    
    func getProfile() -> AnyPublisher<APIResult<ProfileResponse>, APIError> {
        guard accessToken != nil else {
            return Just(.unsuccess(.unauthorized))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        let profileEndpoint = MatrixAPIEndpoints.profile.urlString()
        return performGet(profileEndpoint, expecting: ProfileResponse.self)
    }
    
    func updateProfile(updateProfileRequest: UpdateProfileRequest) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let updateProfileEndpoint = MatrixAPIEndpoints.updateProfile.urlString()
        return performPut(updateProfileEndpoint, updateProfileRequest, expecting: MatrixEmptyResponse.self)
    }
    
    // MARK: - File Upload / Presigned URL
    
    func getPresignedUrl(fileType: String) -> AnyPublisher<APIResult<PresignedUrlResponse>, APIError> {
        let presignedUrlEndpoint = MatrixAPIEndpoints.getPresignedUrl.urlString()
        return performPost(presignedUrlEndpoint, PreSignedUrlRequest(fileType: fileType), expecting: PresignedUrlResponse.self)
    }
    
    // MARK: - Room State
    
    func getRoomState(roomId: String) -> AnyPublisher<APIResult<[Event]>, APIError> {
        let roomStateEndpoint = MatrixAPIEndpoints.getRoomState.urlString(withPathParameters: ["roomId": roomId])
        return performGet(roomStateEndpoint, expecting: [Event].self)
    }
    
    // MARK: - Helper Methods for HTTP Requests
    
    private func performGet<T: Decodable>(_ path: String, expecting: T.Type) -> AnyPublisher<APIResult<T>, APIError> {
        Future { [self] promise in
            Task {
                if let result = await client?.get(path, response: expecting) {
                    promise(.success(result))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performPost<T: Encodable, R: Decodable>(_ path: String, _ body: T, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                if let result = await client?.post(path, body: body, expecting: expecting) {
                    promise(.success(result))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performPut<T: Encodable, R: Decodable>(_ path: String, _ body: T, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                if let result = await client?.put(path, body: body, expecting: expecting) {
                    promise(.success(result))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performDelete<T: Encodable, R: Decodable>(_ path: String, body: T? = nil, expecting: R.Type) -> AnyPublisher<APIResult<R>, APIError> {
        Future { [self] promise in
            Task {
                if let result = await client?.delete(path, body: MatrixEmptyRequest(), expecting: expecting) {
                    promise(.success(result))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func logRequest(endpoint: String, response: Any) {
        // Log successful responses
        print("API Request Successful: \(endpoint)")
        print("Response: \(response)")
    }
    
    private func logRequest(endpoint: String, error: APIError) {
        // Log failed responses
        print("API Request Failed: \(endpoint)")
        print("Error: \(error.localizedDescription)")
    }
}

extension MatrixAPIManager {
    
    // MARK: - Session Restoration
    
    /// Restores the session using an existing access token.
    func restoreSession(accessToken: String) {
        self.accessToken = accessToken
    }
    
    
    // MARK: - Sync with Polling
    
    private func startSyncPollingIfNeeded() {
        guard !isWaitingForSyncResponse else { return }
        isWaitingForSyncResponse = true

        // NOTE: stay on syncQ for the entire chain so no main-thread work happens here.
        syncRooms(since: nextBatch, timeout: 5000)
            .subscribe(on: syncQ)
            .receive(on: syncQ)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                switch completion {
                case .failure(let error):
                    print("[RoomsSync] failed: \(error.localizedDescription)")
                    self.isWaitingForSyncResponse = false
                case .finished:
                    self.isWaitingForSyncResponse = false
                }
            }, receiveValue: { [weak self] response in
                guard let self else { return }

                switch response {
                case .success(let value):
                    if let token = value.nextBatch, token != self.nextBatch {
                        self.nextBatch = token
                        self.syncResponseSubject.send(response)
                    }
                    self.isWaitingForSyncResponse = false

                case .unsuccess:
                    self.isWaitingForSyncResponse = false
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Syncing Rooms
    
    private func syncRooms(since: String? = nil, timeout: Int? = nil) -> AnyPublisher<APIResult<SyncResponse>, APIError> {
        guard accessToken != nil else {
            return Just(.unsuccess(.unauthorized))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        var syncEndpoint = MatrixAPIEndpoints.sync.urlString()
        
        // Add query parameters dynamically if provided
        var urlComponents = URLComponents(string: syncEndpoint)!
        
        var queryItems = [URLQueryItem]()
        
        // Add 'since' parameter if provided
        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: since))
        } else {
            queryItems.append(URLQueryItem(name: "full_state", value: "\(true)"))
        }
        
        // Add 'timeout' parameter if provided
        if let timeout = timeout {
            queryItems.append(URLQueryItem(name: "timeout", value: "\(timeout)"))
        }
        
        // Attach the query items to the URL
        urlComponents.queryItems = queryItems
        syncEndpoint = urlComponents.url!.absoluteString
        
        return performGet(syncEndpoint, expecting: SyncResponse.self)
            .map { result in
                switch result {
                case .success(let response):
                    return .success(response)
                case .unsuccess(let error):
                    return .unsuccess(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    
    func startSyncPolling(nextBatch: String?) {
        syncQ.async { [weak self] in
            guard let self else { return }
            self.nextBatch = nextBatch
            self.startSyncTimer()
        }
    }
    
    func stopSyncPolling() {
        syncQ.async { [weak self] in
            self?.stopSyncTimerOnQueue()
        }
    }
    
    private func stopSyncTimerOnQueue() {
        self.syncTimer?.setEventHandler {}
        self.syncTimer?.cancel()
        self.syncTimer = nil
    }
    
    private func startSyncTimer() {
        stopSyncTimerOnQueue()

        let timer = DispatchSource.makeTimerSource(queue: syncQ)
        // immediate first tick, then long-poll cadence (adjust as needed)
        timer.schedule(deadline: .now(), repeating: .seconds(5), leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.startSyncPollingIfNeeded()
        }
        syncTimer = timer
        timer.resume()
    }
    
    // MARK: - Fetch Messages
    func fetchMessages(
        forRoom roomId: String,
        from: String? = nil,
        limit: Int? = 10,
        dir: String = "f"
    ) -> AnyPublisher<APIResult<GetMessagesResponse>, APIError> {
        let filter = MessagesFilter(types: ["m.room.message", "m.room.encrypted"])
        guard self.accessToken != nil else {
            return Just(.unsuccess(.unauthorized))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        var endpoint = MatrixAPIEndpoints.getMessages
            .urlString(withPathParameters: ["roomId": roomId])

        var urlComponents = URLComponents(string: endpoint)!
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "dir", value: dir))

        if let from, !from.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: from))
        }

        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        let enc = JSONEncoder()
        enc.outputFormatting = []
        if let data = try? enc.encode(filter),
           let json = String(data: data, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "filter", value: json))
        }

        urlComponents.queryItems = queryItems
        endpoint = urlComponents.url!.absoluteString

        return performGet(endpoint, expecting: GetMessagesResponse.self)
            .map { result in
                switch result {
                case .success(let response):
                    return .success(response)
                case .unsuccess(let error):
                    return .unsuccess(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Scheduling Message Fetches Periodically
    
    // Fetch `pages` of messages for a room, walking pagination tokens one-by-one.
    // dir = "b" (backwards) for backfill, "f" for forward.
    
    // Fetch a single page of messages for a room.
    func fetchMessagePage(
        roomId: String,
        from token: String?,
        limit: Int,
        dir: String
    ) -> AnyPublisher<(GetMessagesResponse, String?), APIError> {
        fetchMessages(forRoom: roomId, from: token, limit: limit, dir: dir)
            .tryMap { result -> (GetMessagesResponse, String?) in
                switch result {
                case .success(let response):
                    print("[MatrixAPI] Page fetched for room \(roomId): \(response.chunk.count) messages")
                    return (response, response.end)
                case .unsuccess(let error):
                    print("[MatrixAPI] Failed to fetch page: \(error.localizedDescription)")
                    throw error
                }
            }
            .mapError { $0 as? APIError ?? .unknown }
            .eraseToAnyPublisher()
    }

    // Recursively fetch multiple pages (backfill).
    func backfillMessagesRecursive(
        roomId: String,
        pagesLeft: Int,
        currentToken: String?,
        pageSize: Int,
        dir: String,
        accumulated: [GetMessagesResponse]
    ) -> AnyPublisher<[GetMessagesResponse], APIError> {

        guard pagesLeft > 0 else {
            print("[MatrixAPI] Backfill complete for \(roomId). Total pages: \(accumulated.count)")
            return Just(accumulated)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }

        return fetchMessagePage(roomId: roomId, from: currentToken, limit: pageSize, dir: dir)
            .handleEvents(receiveOutput: { (response, _) in
                // 🔸 Optional side effect: store to DB
                // DBManager.shared.saveMessages(response.chunk.map(...), inRoom: roomId)
            })
            .flatMap { (response, nextToken) -> AnyPublisher<[GetMessagesResponse], APIError> in
                var newAccumulated = accumulated
                newAccumulated.append(response)

                // If no next token, end recursion
                guard let nextToken = nextToken, !nextToken.isEmpty else {
                    print("⚠️ [MatrixAPI] No next token, stopping backfill early.")
                    return Just(newAccumulated)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }

                // Continue to next page
                return self.backfillMessagesRecursive(
                    roomId: roomId,
                    pagesLeft: pagesLeft - 1,
                    currentToken: nextToken,
                    pageSize: pageSize,
                    dir: dir,
                    accumulated: newAccumulated
                )
            }
            .eraseToAnyPublisher()
    }

    /// Public entry point to fetch N pages of messages.
    func backfillMessages(
        roomId: String,
        pages: Int = 3,
        pageSize: Int = 100,
        startFrom: String? = nil,
        dir: String = "b"
    ) -> AnyPublisher<[GetMessagesResponse], APIError> {
        print("[MatrixAPI] Starting backfill for \(roomId) – \(pages) pages, \(pageSize) msgs/page")
        return backfillMessagesRecursive(
            roomId: roomId,
            pagesLeft: pages,
            currentToken: startFrom,
            pageSize: pageSize,
            dir: dir,
            accumulated: []
        )
    }
    
    private func startMessageFetching(forRoom roomId: String) {
        stopMessageFetching()
        let timer = DispatchSource.makeTimerSource(queue: syncQ)
        timer.schedule(deadline: .now(), repeating: .milliseconds(250), leeway: .milliseconds(0))
        timer.setEventHandler { [weak self] in
            self?.startMessageFetchingIfNeeded(forRoom: roomId)
        }
        messageTimer = timer
        timer.resume()
    }
    
    func startSyncMesages(forRoom roomId: String, lastMessageEventId: String? = nil) {
        syncQ.async { [weak self] in
            guard let self else { return }
            self.lastMessageEventId = lastMessageEventId
            self.startMessageFetching(forRoom: roomId)
        }
    }
    
    private func startMessageFetchingIfNeeded(forRoom roomId: String) {
        guard !isWaitingForChatResponse else { return }
        isWaitingForChatResponse = true

        self.fetchMessages(forRoom: roomId, from: self.lastMessageEventId)
            .subscribe(on: syncQ)   // run upstream on background
            .receive(on: DispatchQueue.main)     // handle on background
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch messages: \(error.localizedDescription)")
                }
                self?.isWaitingForChatResponse = false
            }, receiveValue: { [weak self] response in
                guard let self else { return }
                switch response {
                case .success(let messagesResponse):
                    if !messagesResponse.chunk.isEmpty {
                        self.chatMessagesSubject.send(response)
                        self.lastMessageEventId = messagesResponse.end
                    }
                case .unsuccess(let error):
                    print("Error in fetching messages: \(error.localizedDescription)")
                }
                self.isWaitingForChatResponse = false
            })
            .store(in: &self.cancellables)
    }
    
    // Stop message fetching
    func stopMessageFetching() {
        messageTimer?.setEventHandler {}
        messageTimer?.cancel()
        messageTimer = nil
    }
    
    func uploadMedia(fileURL: URL, fileName: String, mimeType: String, onProgress: ((Double) -> Void)? = nil) -> AnyPublisher<APIResult<URL>, APIError> {
        let path = MatrixAPIEndpoints.uploadMedia.urlString()
        var urlComponents = URLComponents(string: path)
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "filename", value: fileName))
        urlComponents?.queryItems = queryItems
        
        
        guard let uploadPath = urlComponents?.url?.absoluteString else {
            return Just(.unsuccess(.invalidURL))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        return Future { [weak self] promise in
            Task {
                guard let self = self else {
                    promise(.success(.unsuccess(.unknown)))
                    return
                }
                let result = await self.client?.upload(
                    path: uploadPath,
                    fileURL: fileURL,
                    mimeType: mimeType,
                    onProgress: onProgress
                )
                if let result = result {
                    promise(.success(result))
                } else {
                    promise(.success(.unsuccess(.unknown)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func downloadMediaFile(
        mxcUrl: String,
        onProgress: ((Double) -> Void)? = nil
    ) -> AnyPublisher<APIResult<URL>, APIError> {
        guard let client = self.client else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        guard let (serverName, mediaId) = parseMXC(mxc: mxcUrl) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        let path = MatrixAPIEndpoints.downloadMedia.urlString(withPathParameters: [
            "serverName": serverName,
            "mediaId": mediaId
        ])

        // Start work only when subscribed, and never on the main actor/thread.
        return Deferred {
            Future<APIResult<URL>, APIError> { promise in
                // Hop to a detached task so we don't inherit MainActor
                Task.detached(priority: .userInitiated) {
                    // Ensure progress callbacks hit the main thread (UI-safe) but keep download off-main
                    let mainProgress: ((Double) -> Void)? = onProgress.map { handler in
                        { value in DispatchQueue.main.async { handler(value) } }
                    }
                    let result = await client.downloadMedia(path: path, onProgress: mainProgress)
                    promise(.success(result))
                }
            }
        }
        // Even if someone subscribes from main, produce on a background queue
        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
        .eraseToAnyPublisher()
    }
    
    // MARK: - Read Receipt (m.read)
    func sendReadMarker(
        roomId: String,
        fullyReadEventId: String? = nil,
        readEventId: String? = nil,
        readPrivateEventId: String? = nil
    ) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        guard let _ = accessToken else {
            return Just(.unsuccess(.unauthorized))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        guard
            (fullyReadEventId?.isEmpty == false) ||
            (readEventId?.isEmpty == false) ||
            (readPrivateEventId?.isEmpty == false)
        else {
            return Just(.unsuccess(.badRequest))
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        
        let endpoint = MatrixAPIEndpoints.sendReceipt.urlString(withPathParameters: [
            "roomId": roomId
        ])

        let request = ReadMarkerRequest(
            mFullyRead: fullyReadEventId ?? "",
            mRead: readEventId,
            mReadPrivate: readPrivateEventId
        )
        return performPost(endpoint, request, expecting: MatrixEmptyResponse.self)
    }
    
    func sendTyping(roomId: String, userId: String, typing: Bool, timeout: Int = 30000) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        return performPut(
            MatrixAPIEndpoints.typing.urlString(withPathParameters: ["roomId": roomId, "userId": userId]),
            TypingRequest(typing: typing, timeout: timeout),
            expecting: MatrixEmptyResponse.self
        )
    }
    
    func deleteMessage(
        roomId: String,
        eventId: String,
        reason: String? = nil
    ) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        return performPut(
            MatrixAPIEndpoints.redact.urlString(
                withPathParameters: ["roomId": roomId, "eventId": eventId, "txnId": UUID().uuidString]
            ),
            RedactEventRequest(reason: reason ?? "User deleted message"),
            expecting: SendMessageResponse.self
        )
    }
    
    func sendReaction(roomId: String, eventId: String, emoji: Emoji) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        let txnId = UUID().uuidString
        
        let endpoint = MatrixAPIEndpoints
            .reaction
            .urlString(
                withPathParameters: [
                    "roomId": roomId,
                    "txnId": txnId
                ]
            )
        
        let request = ReactionRequest(emoji: emoji, eventId: eventId)
        
        return performPut(endpoint, request, expecting: SendMessageResponse.self)
    }
    
    func redactReaction(roomId: String, reactionEventId: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        let txnId = UUID().uuidString
        let endpoint = MatrixAPIEndpoints.redact.urlString(
            withPathParameters: [
                "roomId": roomId,
                "eventId": reactionEventId,
                "txnId": txnId
            ]
        )
        return performPut(
            endpoint,
            RedactEventRequest(reason: "User deleted reaction"),
            expecting: SendMessageResponse.self
        )
    }
    
    func kickFromRoom(roomId: String, userId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let endpoint = MatrixAPIEndpoints.kickFromRoom.urlString(
            withPathParameters: [
                "roomId": roomId,
            ]
        )
        return performPost(
            endpoint,
            KickUserRequest(userId: userId, reason: reason),
            expecting: MatrixEmptyResponse.self
        )
    }
    
    func leaveRoom(roomId: String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let endpoint = MatrixAPIEndpoints.leaveRoom.urlString(
            withPathParameters: [
                "roomId": roomId,
            ]
        )
        return performPost(
            endpoint,
            LeaveRoomRequest(reason: reason),
            expecting: MatrixEmptyResponse.self
        )
    }
    
    func inviteToRoom(roomId: String, userId:String, reason: String) -> AnyPublisher<APIResult<MatrixEmptyResponse>, APIError> {
        let endpoint = MatrixAPIEndpoints.inviteToRoom.urlString(
            withPathParameters: [
                "roomId": roomId,
            ]
        )
        return performPost(
            endpoint,
            InviteUserRequest(userId: userId, reason: reason),
            expecting: MatrixEmptyResponse.self
        )
    }
    
    func updateRoomName(roomId: String, name: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        let endpoint = MatrixAPIEndpoints.updateRoomName.urlString(
            withPathParameters: [
                "roomId": roomId,
            ]
        )
        return performPut(
            endpoint,
            RoomNameRequest(name: name),
            expecting: SendMessageResponse.self
        )
    }
    
    func updateRoomImage(roomId: String, url: String) -> AnyPublisher<APIResult<SendMessageResponse>, APIError> {
        let endpoint = MatrixAPIEndpoints.updateRoomImage.urlString(
            withPathParameters: [
                "roomId": roomId,
            ]
        )
        return performPut(
            endpoint,
            RoomImageRequest(url: url),
            expecting: SendMessageResponse.self
        )
    }
}

extension MatrixAPIManager {

    // MARK: - Push Registration (HTTP Pusher)

    // Registers/updates an HTTP pusher for this device.
    // Matrix spec: POST /_matrix/client/v3/pushers/set  (body is MatrixPusherSetRequest)
    func registerPusher(request: MatrixPusherSetRequest) -> AnyPublisher<Void, Error> {
        let path = MatrixAPIEndpoints.pushersSet.urlString()
        return performPost(path, request, expecting: MatrixEmptyResponse.self)
            .tryMap { result in
                switch result {
                case .success:
                    return ()
                case .unsuccess(let apiError):
                    throw apiError
                }
            }
            .eraseToAnyPublisher()
    }

    // Unregisters an HTTP pusher by app_id + pushkey.
    // Matrix spec: POST /_matrix/client/v3/pushers/delete  (body: { app_id, pushkey })
    func deletePusher(request: MatrixPusherDeleteRequest) -> AnyPublisher<Void, Error> {
        let path = MatrixAPIEndpoints.pusherDelete.urlString()

        return performPost(path, request, expecting: MatrixEmptyResponse.self)
            .tryMap { result in
                switch result {
                case .success:
                    return ()
                case .unsuccess(let apiError):
                    throw apiError
                }
            }
            .eraseToAnyPublisher()
    }
}
