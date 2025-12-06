//
//  MediaCacheManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/07/25.
//

import Foundation
import Combine
import UIKit
import RealmSwift
import CryptoKit

// MARK: - MediaCacheManager

/// Refactored, non-blocking, coalesced media cache/downloader.
/// - Deduplicates concurrent downloads per URL
/// - Throttles progress + metadata writes
/// - Never writes to Realm on the main thread
/// - Stores only the filename in Realm; resolves to full path when needed
final class MediaCacheManager: ObservableObject {

    // MARK: Types

    struct Config {
        /// Minimum interval between progress emissions to UI/DB
        var minProgressInterval: CFTimeInterval = 1.0 / 12.0  // ~12 fps
        /// Minimum delta change in progress to emit
        var minProgressDelta: Double = 0.02                    // 2%
        /// Cache folder under Library/Caches/
        var folderName: String = "MediaCache"
    }

    private struct TaskState {
        var progressHandlers: [(Double) -> Void] = []
        var completionHandlers: [(Result<String, Error>) -> Void] = []
        var cancellable: AnyCancellable?
        var lastEmit: CFAbsoluteTime = 0
        var lastValue: Double = -1
    }

    // MARK: Public API

    static let shared = MediaCacheManager()
    var config = Config()

    // MARK: Dependencies

    private let fileManager = FileManager.default
    private let matrixApiManager: MatrixAPIManagerProtocol =
        DIContainer.shared.container.resolve(MatrixAPIManagerProtocol.self)!

    // MARK: State (thread-safe)

    /// url -> absolute local path
    private var memoryCache: [String: String] = [:]
    /// url -> task state (progress/completions/cancellable)
    private var downloadTasks: [String: TaskState] = [:]

    /// Protects `memoryCache` and `downloadTasks`
    private let stateQ = DispatchQueue(
        label: "yal.media.cache.state",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// File I/O (moves/copies/checks)
    private let ioQ = DispatchQueue(
        label: "yal.media.cache.io",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// DB metadata writes (serialized to avoid write conflicts)
    private let metadataQ = DispatchQueue(label: "yal.media.cache.metadata", qos: .utility)

    /// Throttle map for DB persistence: url -> (lastTime, lastValue)
    private var persistMap: [String: (CFAbsoluteTime, Double)] = [:]

    /// Combine storage
    private var cancellables = Set<AnyCancellable>()

    // MARK: Paths

    private lazy var cacheRootURL: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent(config.folderName, isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    // MARK: Init

    private init() {}

    // MARK: - Public Methods

    /// Main API: Get media from cache or network. Will update Realm with progress & state.
    func getMedia(
        url: String,
        type: MediaType,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if let path = stateRead({ memoryCache[url] }),
           fileManager.fileExists(atPath: path) {
            DispatchQueue.main.async { completion(.success(path)) }
            persist(url: url, type: type, state: .downloaded, path: path, progress: 1.0, force: true)
            return
        }

        ioQ.async { [weak self] in
            guard let self else { return }

            if let cached = self.realmGetCachedMedia(url: url) {
                let full = self.resolveFullURL(from: cached.fileName)
                if self.fileManager.fileExists(atPath: full.path),
                   cached.state == .downloaded {
                    let path = full.path
                    self.stateWrite { self.memoryCache[url] = path }
                    DispatchQueue.main.async { completion(.success(path)) }
                    self.persist(url: url, type: type, state: .downloaded, path: path, progress: 1.0, force: true)
                    return
                }
            }

            let shouldStart: Bool = self.stateWriteSync {
                if var s = self.downloadTasks[url] {
                    s.progressHandlers.append(progressHandler)
                    s.completionHandlers.append(completion)
                    self.downloadTasks[url] = s
                    return false
                } else {
                    self.downloadTasks[url] = TaskState(
                        progressHandlers: [progressHandler],
                        completionHandlers: [completion],
                        cancellable: nil,
                        lastEmit: 0,
                        lastValue: -1
                    )
                    return true
                }
            }

            if shouldStart {
                self.persist(url: url, type: type, state: .downloading, path: "", progress: 0.0, force: true)
                self.startDownload(url: url, type: type)
            }
        }
    }

    func clearOldCache(maxItems: Int = 1000) {
        ioQ.async { [weak self] in
            guard let self else { return }
            let entries = self.realmFetchAllCachedMediaSortedByLastUsed()
            guard !entries.isEmpty else { return }

            let overflow = max(0, entries.count - maxItems)
            guard overflow > 0 else { return }

            let toDelete = entries.prefix(overflow)
            // Remove files
            for e in toDelete {
                let full = self.resolveFullURL(from: e.fileName)
                if self.fileManager.fileExists(atPath: full.path) {
                    try? self.fileManager.removeItem(at: full)
                }
            }
            // Remove rows
            self.realmDeleteCachedMedia(ids: Array(toDelete.map { $0.id }))
        }
    }

    func clearAllCache() {
        ioQ.async { [weak self] in
            guard let self else { return }
            self.realmDeleteAllCachedMedia()
            try? self.fileManager.removeItem(at: self.cacheRootURL)
            try? self.fileManager.createDirectory(at: self.cacheRootURL, withIntermediateDirectories: true)
            self.stateWrite { self.memoryCache.removeAll() }
        }
    }

    func warmMemoryCacheFromRealm(maxItems: Int = 1000, purgeMissing: Bool = true) {
        ioQ.async { [weak self] in
            guard let self else { return }
            let list = self.realmFetchAllCachedMediaSortedByLastUsed(desc: true)

            var loaded = 0
            var missingIds: [String] = []

            for row in list {
                if loaded >= maxItems { break }
                let full = self.resolveFullURL(from: row.fileName)
                if row.state == .downloaded,
                   !full.path.isEmpty,
                   self.fileManager.fileExists(atPath: full.path) {
                    self.stateWrite { self.memoryCache[row.id] = full.path }
                    loaded += 1
                } else if purgeMissing {
                    missingIds.append(row.id)
                }
            }

            if purgeMissing, !missingIds.isEmpty {
                self.realmDeleteCachedMedia(ids: missingIds)
            }
        }
    }

    // Helpers (kept)

    func path(for url: String) -> String? {
        stateRead { memoryCache[url] }
    }

    private func setPath(_ path: String, for url: String) {
        stateWrite { [self] in memoryCache[url] = path }
    }

    private func removePath(for url: String) {
        stateWrite { [self] in memoryCache.removeValue(forKey: url) }
    }

    // MARK: - Download Logic

    private func startDownload(url: String, type: MediaType) {
        let cancellable = matrixApiManager
            .downloadMediaFile(
                mxcUrl: url,
                onProgress: { [weak self] p in
                    self?.emitProgress(url: url, type: type, raw: p)
                }
            )
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                if case .failure(let e) = completion {
                    self.finish(url: url, result: .failure(e))
                    self.persist(url: url, type: type, state: .failed, path: "", progress: 0.0, force: true)
                }
            }, receiveValue: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let tempURL):
                    self.ioQ.async {
                        self.finalizeSuccess(url: url, type: type, tempURL: tempURL)
                    }
                case .unsuccess(let apiError):
                    self.finish(url: url, result: .failure(apiError))
                    self.persist(url: url, type: type, state: .failed, path: "", progress: 0.0, force: true)
                }
            })

        stateWrite { [self] in
            if var s = downloadTasks[url] {
                s.cancellable = cancellable
                downloadTasks[url] = s
            }
        }
    }

    private func emitProgress(url: String, type: MediaType, raw: Double) {
        let value = max(0.0, min(1.0, raw))

        // Atomically read/mutate state and capture handlers
        let (handlers, shouldEmit): ([(Double) -> Void], Bool) = stateWriteSync {
            guard var s = downloadTasks[url] else { return ([], false) }
            let now = CFAbsoluteTimeGetCurrent()
            let doEmit =
                value <= 0.0 || value >= 1.0 ||
                (now - s.lastEmit) >= config.minProgressInterval ||
                abs(value - s.lastValue) >= config.minProgressDelta

            if doEmit {
                s.lastEmit = now
                s.lastValue = value
                let hs = s.progressHandlers
                downloadTasks[url] = s
                return (hs, true)
            } else {
                return ([], false)
            }
        }

        guard shouldEmit else { return }
        DispatchQueue.main.async { handlers.forEach { $0(value) } }
        persist(url: url, type: type, state: .downloading, path: "", progress: value, force: false)
    }

    private func finalizeSuccess(url: String, type: MediaType, tempURL: URL) {
        // Preserve extension if provided
        let ext = tempURL.pathExtension
        let baseName = url.sha256 + (ext.isEmpty ? "" : ".\(ext)")
        let finalURL = cacheRootURL.appendingPathComponent(baseName, isDirectory: false)

        if fileManager.fileExists(atPath: finalURL.path) {
            try? fileManager.removeItem(at: finalURL)
        }
        do {
            try fileManager.moveItem(at: tempURL, to: finalURL)
        } catch {
            _ = try? fileManager.copyItem(at: tempURL, to: finalURL)
            try? fileManager.removeItem(at: tempURL)
        }

        let path = finalURL.path
        setPath(path, for: url)

        DispatchQueue.main.async {
            self.finish(url: url, result: .success(path))
        }
        persist(url: url, type: type, state: .downloaded, path: path, progress: 1.0, force: true)
    }

    @inline(__always)
    private func finish(url: String, result: Result<String, Error>) {
        let completions: [(Result<String, Error>) -> Void] = stateWriteSync {
            if let s = downloadTasks[url] {
                s.cancellable?.cancel()
                downloadTasks[url] = nil
                return s.completionHandlers
            }
            return []
        }

        guard !completions.isEmpty else { return }
        DispatchQueue.main.async {
            completions.forEach { $0(result) }
        }
    }

    // MARK: - Metadata / Realm (throttled, off-main)

    /// Coalesces progress writes; always off-main.
    private func persist(
        url: String,
        type: MediaType,
        state: MediaDownloadState,
        path: String,
        progress: Double,
        force: Bool
    ) {
        metadataQ.async { [weak self] in
            guard let self else { return }
            let now = CFAbsoluteTimeGetCurrent()

            var shouldWrite = force
            if !force {
                let last = self.persistMap[url] ?? (0, -1)
                if (now - last.0) >= self.config.minProgressInterval ||
                    abs(progress - last.1) >= self.config.minProgressDelta ||
                    state == .downloaded || state == .failed {
                    shouldWrite = true
                }
            }

            guard shouldWrite else { return }
            self.persistMap[url] = (now, progress)

            let fileName = path.isEmpty ? "" : URL(fileURLWithPath: path).lastPathComponent

            do {
                try DBManager.shared.write { realm in
                    let entry = realm.object(ofType: CachedMedia.self, forPrimaryKey: url)
                        ?? CachedMedia(id: url, path: fileName, type: type)

                    entry.downloadState = state
                    entry.lastUsed = Date()
                    entry.progress = progress
                    if !fileName.isEmpty { entry.localPath = fileName }
                    realm.add(entry, update: .modified)
                }
            } catch {
                print("[MediaCacheManager] persist write failed: \(error)")
            }
        }
    }

    // MARK: - Original helpers (kept)

    private func updateMetadata(url: String, type: MediaType, state: MediaDownloadState, path: String, progress: Double) {
        persist(url: url, type: type, state: state, path: path, progress: progress, force: false)
    }

    private func normalizePath(_ s: String) -> String {
        guard !s.isEmpty else { return "" }
        if s.hasPrefix("file://"), let u = URL(string: s) { return u.path }
        return s
    }

    private func invokeCompletions(for url: String, result: Result<String, Error>) {
        finish(url: url, result: result)
    }

    private func invokeProgress(for url: String, progress: Double) {
        var handlers: [(Double) -> Void] = []
        stateRead {
            handlers = downloadTasks[url]?.progressHandlers ?? []
        }
        guard !handlers.isEmpty else { return }
        DispatchQueue.main.async { handlers.forEach { $0(progress) } }
    }

    // MARK: - Path helpers

    private func fullURL(forStoredFileName name: String) -> URL {
        cacheRootURL.appendingPathComponent(name, isDirectory: false)
    }

    /// If `stored` is absolute and exists, return it;
    /// otherwise resolve to current container + lastPathComponent.
    private func resolveFullURL(from stored: String) -> URL {
        guard !stored.isEmpty else { return cacheRootURL }
        let absolute = URL(fileURLWithPath: stored)
        if absolute.path.hasPrefix("/"),
           fileManager.fileExists(atPath: absolute.path) {
            return absolute
        }
        return fullURL(forStoredFileName: absolute.lastPathComponent)
    }

    // MARK: - Realm accessors

    private func realmGetCachedMedia(url: String) -> (id: String, fileName: String, state: MediaDownloadState)? {
        do {
            return try DBManager.shared.withRealm { r in
                if let e = r.object(ofType: CachedMedia.self, forPrimaryKey: url) {
                    return (id: e.id, fileName: e.localPath, state: e.downloadState)
                }
                return nil
            }
        } catch {
            print("[MediaCacheManager] realmGetCachedMedia error:", error)
            return nil
        }
    }

    private func realmFetchAllCachedMediaSortedByLastUsed(desc: Bool = true) -> [(id: String, fileName: String, state: MediaDownloadState, lastUsed: Date)] {
        do {
            return try DBManager.shared.withRealm { r in
                let results = r.objects(CachedMedia.self).sorted(byKeyPath: "lastUsed", ascending: !desc)
                return results.map { (id: $0.id, fileName: $0.localPath, state: $0.downloadState, lastUsed: $0.lastUsed) }
            }
        } catch {
            print("[MediaCacheManager] fetchAll error:", error)
            return []
        }
    }

    private func realmDeleteCachedMedia(ids: [String]) {
        guard !ids.isEmpty else { return }
        do {
            try DBManager.shared.write { r in
                let objs = r.objects(CachedMedia.self).filter("id IN %@", ids)
                r.delete(objs)
            }
        } catch {
            print("[MediaCacheManager] delete ids error:", error)
        }
    }

    private func realmDeleteAllCachedMedia() {
        do {
            try DBManager.shared.write { r in
                r.delete(r.objects(CachedMedia.self))
            }
        } catch {
            print("[MediaCacheManager] delete all error:", error)
        }
    }

    // MARK: - Concurrency helpers

    @inline(__always)
    private func stateRead<T>(_ block: () -> T) -> T {
        stateQ.sync(execute: block)
    }

    /// Synchronous barrier write (fixes `shouldStart` race).
    @inline(__always)
    private func stateWriteSync<T>(_ block: () -> T) -> T {
        stateQ.sync(flags: .barrier, execute: block)
    }

    @inline(__always)
    private func stateWrite(_ block: @escaping () -> Void) {
        stateQ.async(flags: .barrier, execute: block)
    }
}

// MARK: - Extras

enum MediaCacheError: Error {
    case invalidURL
    case unknown
}

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
