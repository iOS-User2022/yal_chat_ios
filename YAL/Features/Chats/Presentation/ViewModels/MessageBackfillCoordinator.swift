//
//  MessageBackfillCoordinator.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/10/25.
//


import Combine
import Foundation

final class MessageBackfillCoordinator {
    private let api: MatrixAPIManagerProtocol
    private weak var repo: ChatRepository?
    private var cancellables = Set<AnyCancellable>()

    private let requestSubject = PassthroughSubject<(roomId: String, targetCount: Int), Never>()

    private var inFlight = Set<String>()
    private var pending: [String: Int] = [:]
    private let lock = NSLock()

    private let debounceQueue = DispatchQueue(label: "message.backfill.debounce")
    private let interFetchDelay: TimeInterval = 1.0

    private let workQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "messages.backfill.queue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 4   // a bit more conservative
        return q
    }()

    init(api: MatrixAPIManagerProtocol, repo: ChatRepository) {
        self.api = api
        self.repo = repo

        requestSubject
            // .debounce(for: .milliseconds(150), scheduler: debounceQueue)
            .sink { [weak self] pair in
                self?.schedule(roomId: pair.roomId, targetCount: pair.targetCount)
            }
            .store(in: &cancellables)
    }

    /// Public API
    func enqueue(roomId: String, targetCount: Int = 15) {
        lock.lock()
        // if already running, remember the wanted count and bail
        if inFlight.contains(roomId) {
            pending[roomId] = targetCount
            lock.unlock()
            return
        }
        lock.unlock()

        requestSubject.send((roomId, targetCount))
    }

    private func schedule(roomId: String, targetCount: Int) {
        lock.lock()
        if inFlight.contains(roomId) {
            // someone tried to schedule while we were deciding
            pending[roomId] = targetCount
            lock.unlock()
            return
        }
        inFlight.insert(roomId)
        lock.unlock()

        workQueue.addOperation { [weak self] in
            self?.runBackfillOnePage(roomId: roomId, targetCount: targetCount)
        }
    }

    /// Fetch a single page and stop
    private func runBackfillOnePage(
        roomId: String,
        targetCount: Int = 10,
        dir: Direction = .backward
    ) {
        let startFrom = DBManager.shared.fetchMessageSync(for: roomId)?.firstEvent
        let finished = DispatchSemaphore(value: 0)

        var cancel: AnyCancellable?
        cancel = fetchMessagesPage(roomId: roomId, from: startFrom, limit: targetCount, dir: dir)
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.finish(roomId: roomId)
                    finished.signal()
                },
                receiveValue: { [weak self] response, _ in
                    guard let self, let repo = self.repo else { return }
                    // process via repo
                    repo.handleChatSyncResponse(chatMessageResponse: response)
                    if let end = response.end, dir == .backward {
                        DBManager.shared.saveMessageSync(roomId: roomId, firstEvent: end, lastEvent: nil)
                    }
                }
            )

        // block this operation until the publisher completes
        finished.wait()
        cancel?.cancel()
    }
    
    private func finish(roomId: String) {
        let delay = interFetchDelay
        // we push the actual cleanup to later, without blocking a thread
        if delay > 0 {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                self.finishNow(roomId: roomId)
            }
        } else {
            finishNow(roomId: roomId)
        }
    }
    
    private func finishNow(roomId: String) {
        var followUp: Int?
        lock.lock()
        inFlight.remove(roomId)
        followUp = pending.removeValue(forKey: roomId)
        lock.unlock()
        
        if let count = followUp {
            // schedule the queued-up request
            schedule(roomId: roomId, targetCount: count)
        }
    }

    // MARK: - network

    private func fetchMessagesPage(
        roomId: String,
        from: String?,
        limit: Int,
        dir: Direction
    ) -> AnyPublisher<(GetMessagesResponse, String?), APIError> {
        api.fetchMessages(forRoom: roomId, from: from, limit: limit, dir: dir.rawValue)
            .tryMap { result -> (GetMessagesResponse, String?) in
                switch result {
                case .success(let res):
                    print("📥 one-page fetch \(roomId) from=\(from ?? "nil") count=\(res.chunk.count)")
                    return (res, res.end)
                case .unsuccess(let e):
                    throw e
                }
            }
            .mapError { $0 as? APIError ?? .unknown }
            .eraseToAnyPublisher()
    }
}
