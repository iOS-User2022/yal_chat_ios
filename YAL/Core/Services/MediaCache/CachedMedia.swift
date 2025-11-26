//
//  MediaDownloadState.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/07/25.
//


import Foundation
import RealmSwift

enum MediaDownloadState: String, PersistableEnum {
    case notStarted
    case downloading
    case downloaded
    case failed
}

class CachedMedia: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String // URL string (or hash)
    @Persisted var localPath: String
    @Persisted var downloadState: MediaDownloadState
    @Persisted var lastUsed: Date
    @Persisted var progress: Double
    @Persisted var mediaType: MediaType // "image", "video", "document"

    convenience init(id: String, path: String, type: MediaType) {
        self.init()
        self.id = id
        self.localPath = path
        self.mediaType = type
        self.downloadState = .notStarted
        self.lastUsed = Date()
        self.progress = 0.0
    }
}
