//
//  ChatMessageModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 05/05/25.
//


import Foundation
import Combine
import UIKit


struct LinkPreviewData: Codable {
    var url: String
    var title: String?
    var description: String?
    var imageUrl: String?
    var siteName: String?
    var favicon: String?

}
struct ReceiptUpdate {
    let eventId: String
    let receipts: [MessageReadReceipt]
}

struct TypingUpdate {
    let roomId: String
    let userIds: [String]
}

//enum MediaDownloadState: Equatable {
//    case notStarted
//    case downloading
//    case downloaded
//    case failed
//}

class MessageReadReceipt: ObservableObject, Identifiable, Codable {
    @Published var userId: String?
    @Published var timestamp: Int64?
    @Published var status: MessageStatus?
    
    init(userId: String? = nil, timestamp: Int64? = nil, status: MessageStatus? = .sent) {
        self.userId = userId
        self.timestamp = timestamp
        self.status = status
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case timestamp
        case status
    }
    
    // MARK: - Decodable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.timestamp = try container.decodeIfPresent(Int64.self, forKey: .timestamp)
        self.status = try container.decodeIfPresent(MessageStatus.self, forKey: .status)
    }
    
    // MARK: - Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

class MessageReaction: Codable, Equatable {
    static func == (lhs: MessageReaction, rhs: MessageReaction) -> Bool {
        lhs.eventId == rhs.eventId &&
        lhs.userId == rhs.userId &&
        lhs.key == rhs.key &&
        lhs.timestamp == rhs.timestamp
    }
    
    var eventId: String
    var userId: String
    var key: String
    var timestamp: Int64
    
    init(eventId: String, userId: String, key: String, timestamp: Int64) {
        self.eventId = eventId
        self.userId = userId
        self.key = key
        self.timestamp = timestamp
    }
}

class ChatMessageModel: ObservableObject, Identifiable, Equatable, Hashable {
    // MARK: - Core Properties
    @Published var isSelected: Bool = false
    @Published var isRedacted: Bool = false
    @Published var localPreviewImage: UIImage?
    @Published var eventId: String
    @Published var sender: String
    @Published var content: String
    @Published var timestamp: Int64
    @Published var msgType: String
    @Published var mediaUrl: String?
    @Published var mediaInfo: MediaInfo?
    @Published var messageStatus: MessageStatus = .sent
    @Published var receipts: [MessageReadReceipt] = [] {
        didSet {
            bindReceiptStatusUpdates()
        }
    }
    @Published var downloadState: MediaDownloadState
    @Published var downloadProgress: Double
    @Published var inReplyTo: ChatMessageModel?
    @Published var reactions: [MessageReaction] = []

    var linkPreview: LinkPreviewData?

    // Add this property for URL preview
      @Published var urlPreview: URLPreviewData?
    // MARK: - Constants
    let currentUserId: String
    let roomId: String
    
    // MARK: - Identity
    var id: String { eventId }
    
    // MARK: - Computed
    var isReceived: Bool { currentUserId != sender }
    var isTextMessage: Bool { msgType == MessageType.text.rawValue }
    var isImageMessage: Bool { msgType == MessageType.image.rawValue }
    var isVideoMessage: Bool { msgType == MessageType.video.rawValue }
    var isFileMessage: Bool { msgType == MessageType.file.rawValue }
    var isAudioMessage: Bool { msgType == MessageType.audio.rawValue }
    
    var formattedContent: String { content }
    var mediaThumbnail: String? { mediaInfo?.thumbnailUrl }
    var mediaSize: String? {
        guard let size = mediaInfo?.size else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    
    // Add this property to store preview metadata
       var urlPreviewData: URLPreviewData? {
           get {
               // Retrieve from cache or stored metadata
               if let firstURL = self.firstURL {
                   return URLPreviewCache.shared.getPreview(for: firstURL)
               }
               return nil
           }
           set {
               if let preview = newValue {
                   URLPreviewCache.shared.setPreview(preview, for: preview.url)
               }
           }
       }
    
   
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    init(
        eventId: String,
        sender: String,
        content: String,
        timestamp: Int64,
        msgType: String,
        mediaUrl: String? = nil,
        mediaInfo: MediaInfo? = nil,
        userId: String,
        roomId: String,
        receipts: [MessageReadReceipt] = [],
        downloadState: MediaDownloadState = .notStarted,
        downloadProgress: Double = 0.0,
        messageStatus: MessageStatus = .sent,
        inReplyTo: ChatMessageModel? = nil,
        linkPreview: LinkPreviewData? = nil  // Add this

    ) {
        self.eventId = eventId
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.msgType = msgType
        self.mediaUrl = mediaUrl
        self.mediaInfo = mediaInfo
        self.currentUserId = userId
        self.roomId = roomId
        self.receipts = receipts
        self.downloadState = downloadState
        self.downloadProgress = downloadProgress
        self.messageStatus = messageStatus
        self.inReplyTo = inReplyTo
        self.linkPreview = linkPreview

        bindReceiptStatusUpdates()
    }
    
    init(
        message: Message,
        roomId: String,
        currentUserId: String,
        members: [ContactModel]
    ) {
        self.eventId = message.eventId ?? ""
        self.sender = message.sender ?? ""
        self.content = message.content?.body ?? ""
        self.timestamp = message.originServerTs ?? 0
        self.msgType = message.content?.msgType ?? "m.text"
        self.mediaUrl = message.content?.url
        self.mediaInfo = message.content?.info
        self.currentUserId = currentUserId
        self.roomId = roomId
        self.downloadState = .notStarted
        self.downloadProgress = 0.0
        
        if message.sender == currentUserId {
            self.receipts = members
                .filter { $0.userId != currentUserId } // Exclude current user
                .map { MessageReadReceipt(userId: $0.userId, timestamp: 0, status: .sent) }
            self.messageStatus = .sent
        }
        
        bindReceiptStatusUpdates()
    }
    
    init(from object: MessageObject, currentUserId: String, inReplyTo: ChatMessageModel? = nil) {
        self.eventId = object.eventId
        self.roomId = object.roomId
        self.content = object.content
        self.sender = object.sender
        self.timestamp = object.timestamp
        self.messageStatus = MessageStatus(rawValue: object.messageStatus ?? "sent") ?? .sent
        self.mediaUrl = object.mediaUrl
        self.msgType = object.msgType
        if let mediaInfoEntity = object.mediaInfo {
            self.mediaInfo = mediaInfoEntity.toModel()
        }
        self.currentUserId = currentUserId
        self.downloadState = .notStarted
        self.downloadProgress = 0.0
        self.inReplyTo = inReplyTo
        self.reactions = object.reactions.map {
            MessageReaction(
                eventId: $0.eventId,
                userId: $0.userId,
                key: $0.key,
                timestamp: $0.timestamp
            )
        }
        // Add link preview deserialization
              if let previewData = object.linkPreviewData {
                  self.linkPreview = try? JSONDecoder().decode(LinkPreviewData.self, from: previewData)
              }
        bindReceiptStatusUpdates()
    }
    convenience init(from obj: MessageObject, currentUserId: String) {
           let receipts = (try? JSONDecoder().decode([MessageReadReceipt].self, from: obj.receipts ?? Data())) ?? []
           let linkPreview = obj.linkPreviewData.flatMap { try? JSONDecoder().decode(LinkPreviewData.self, from: $0) }
           
           self.init(
               eventId: obj.eventId,
               sender: obj.sender,
               content: obj.content,
               timestamp: obj.timestamp,
               msgType: obj.msgType,
               mediaUrl: obj.mediaUrl,
               mediaInfo: obj.mediaInfo?.toModel(),
               userId: currentUserId,
               roomId: obj.roomId,
               receipts: receipts,
               messageStatus: MessageStatus(rawValue: obj.messageStatus ?? "sent") ?? .sent,
               linkPreview: linkPreview
           )
           
           self.reactions = obj.reactions.map { r in
               MessageReaction(eventId: r.eventId, userId: r.userId, key: r.key, timestamp: r.timestamp)
           }
       }
    func update(receiptEvent: ReceiptEvent) {
        receiptEvent.read?.forEach { userId, info in
            let receiptModel = receipts.first(where: { $0.userId == userId })
            receiptModel?.status = .read
            receiptModel?.timestamp = info.ts
        }
    }
    
    private func bindReceiptStatusUpdates() {
        cancellables.removeAll()

        Publishers.MergeMany(
            receipts.map { $0.$status.eraseToAnyPublisher() }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.evaluateMessageStatus()
        }
        .store(in: &cancellables)
    }
    
    private func evaluateMessageStatus() {
        let relevantReceipts = receipts.filter {
            $0.userId != currentUserId
        }

        let allRead = !relevantReceipts.isEmpty && relevantReceipts.allSatisfy {
            $0.status == .read
        }

        self.messageStatus = allRead ? .read : .sent
    }
    
    static func == (lhs: ChatMessageModel, rhs: ChatMessageModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable Conformance
    func isSelectedFromSearch(searchString: String) -> Bool {
        return self.content.lowercased().contains(searchString.lowercased())
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ForwardPayload: Identifiable {
    let id = UUID()
    var messages: [ChatMessageModel]
}
