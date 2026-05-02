//
//  MediaMessageRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 19/05/25.
//


import Foundation

struct MessageRequest: Request {
    let body: String
    let msgtype: String
    let url: String?
    let filename: String?
    let info: MediaInfoRequest?
    var relatesTo: RelatesToRequest?
    let newContent: NewContentRequest?
    var callId: String?
    var lifetime: String?
    var invitee: String?
    var offer: Offer?
    var partyId: String?
    var sdpStreamMetadata: [StreamMetadata]?
    var version: Int64 = 0
    
    enum CodingKeys: String, CodingKey {
        case body, msgtype, url, filename, info, lifetime, invitee
        case relatesTo = "m.relates_to"
        case newContent = "m.new_content"
        case callId = "call_id"
        case partyId = "party_id"
        case sdpStreamMetadata = "sdp_stream_metadata"
    }

    init(
        body: String,
        msgtype: MessageType,
        url: String? = nil,
        filename: String? = nil,
        info: MediaInfoRequest? = nil,
        replyToEventId: String? = nil,
        newContent: NewContentRequest? = nil,
        callId: String? = nil,
        lifetime: String? = nil,
        invitee: String? = nil,
        offer: Offer? = nil,
        partyId: String? = nil,
        sdpStreamMetadata: [StreamMetadata]? = nil,
        version: Int64 = 0
    ) {
        self.body = body
        self.msgtype = msgtype.rawValue
        self.url = url
        self.filename = filename
        self.info = info
        if let replyToEventId = replyToEventId {
            self.relatesTo = RelatesToRequest(inReplyTo: InReplyToRequest(eventId: replyToEventId))
        } else {
            self.relatesTo = nil
        }
        if let replyToEventId = replyToEventId, msgtype == .videoCall || msgtype == .voiceCall  {
            self.newContent = NewContentRequest(msgtype: msgtype.rawValue, body: body)
            self.relatesTo = RelatesToRequest(relType: "m.replace", eventId: replyToEventId)
        } else {
            self.newContent = nil
        }
        self.callId = callId
        self.lifetime = lifetime
        self.invitee = invitee
        self.offer = offer
        self.partyId = partyId
        self.sdpStreamMetadata = sdpStreamMetadata
        self.version = 0
        
    }

    init(fromText body: String, replyToEventId: String? = nil, msgtype: MessageType) {
        self.init(body: body, msgtype: msgtype, replyToEventId: replyToEventId)
    }

    init?(from message: ChatMessageModel) {
        let msgType = MessageType(rawValue: message.msgType) ?? .file

        if msgType == .text{
            self.init(fromText: message.content, replyToEventId: message.inReplyTo?.eventId, msgtype: msgType)
            return
        }

        if msgType == .voiceCall || msgType == .videoCall{
            self.init(
                body: message.content,
                msgtype: msgType,
                replyToEventId: (message.callId == "changeStatus") ? message.eventId : nil,
                callId: message.callId,
                lifetime: message.lifetime,
                invitee: message.invitee,
                offer: message.offer,
                partyId: message.partyId,
                sdpStreamMetadata: message.sdpStreamMetadata,
                version: 0
            )
            return
        }
        guard
            let url = message.mediaUrl,
            let mediaInfo = message.mediaInfo,
            let mimetype = mediaInfo.mimetype,
            let size = mediaInfo.size
        else {
            return nil
        }

        let thumbnailInfo: ThumbnailInfoRequest? = {
            guard
                let thumb = mediaInfo.thumbnailInfo,
                let w = thumb.w, let h = thumb.h,
                let s = thumb.size, let m = thumb.mimetype
            else { return nil }

            return ThumbnailInfoRequest(mimetype: m, w: w, h: h, size: s)
        }()

        let info = MediaInfoRequest(
            mimetype: mimetype,
            size: size,
            duration: mediaInfo.duration,
            w: mediaInfo.w,
            h: mediaInfo.h,
            thumbnail_url: mediaInfo.thumbnailUrl,
            thumbnail_info: thumbnailInfo
        )

        self.init(
            body: message.content,
            msgtype: msgType,
            url: url,
            filename: message.content,
            info: info,
            replyToEventId: message.inReplyTo?.eventId
        )
    }
}

struct MediaInfoRequest: Codable {
    let mimetype: String
    let size: Int
    let duration: Int?
    let w: Int?
    let h: Int?
    let thumbnail_url: String?
    let thumbnail_info: ThumbnailInfoRequest?

    enum CodingKeys: String, CodingKey {
        case mimetype
        case size
        case duration
        case w
        case h
        case thumbnail_url
        case thumbnail_info
    }
    
    init(
        mimetype: String,
        size: Int,
        duration: Int? = nil,
        w: Int? = nil,
        h: Int? = nil,
        thumbnail_url: String? = nil,
        thumbnail_info: ThumbnailInfoRequest? = nil
    ) {
        self.mimetype = mimetype
        self.size = size
        self.duration = duration
        self.w = w
        self.h = h
        self.thumbnail_url = thumbnail_url
        self.thumbnail_info = thumbnail_info
    }
}

struct ThumbnailInfoRequest: Codable {
    let mimetype: String
    let w: Int
    let h: Int
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case mimetype
        case w
        case h
        case size
    }
    
    init(mimetype: String, w: Int, h: Int, size: Int) {
        self.mimetype = mimetype
        self.w = w
        self.h = h
        self.size = size
    }
}

// MARK: - Reply Structs

struct RelatesToRequest: Codable {
    let inReplyTo: InReplyToRequest?
    let key: String?
    let relType: String?
    let eventId: String?
    
    enum CodingKeys: String, CodingKey {
        case inReplyTo = "m.in_reply_to"
        case key
        case relType = "rel_type"
        case eventId = "event_id"
    }
    
    init(inReplyTo: InReplyToRequest? = nil, key: String? = nil, relType: String? = nil, eventId: String? = nil) {
        self.inReplyTo = inReplyTo
        self.key = key
        self.relType = relType
        self.eventId = eventId
    }
}

struct InReplyToRequest: Codable {
    let eventId: String
    let key: String?
    let relationType: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case key
        case relationType = "rel_type"
    }
    
    init(eventId: String, key: String? = nil, relationType: String? = nil) {
        self.eventId = eventId
        self.key = key
        self.relationType = relationType
    }
}

// MARK: - Reply Structs

struct NewContentRequest: Codable {
    let msgtype: String?
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case msgtype
        case body
    }
    
    init(msgtype: String? = nil, body: String? = nil) {
        self.msgtype = msgtype
        self.body = body
    }
}
