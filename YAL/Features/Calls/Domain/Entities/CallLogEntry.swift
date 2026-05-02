//
//  CallLogEntry.swift
//  YAL
//
//  Created by Sheetal Jha on 26/09/25.
//

import Foundation

class CallLogEntry: Identifiable {
    let id = UUID()
    let contactId: String
    let contactName: String
    let contactPhoneNumber: String
    let contactAvatarURL: String?
    let callType: CallLogType
    let callDirection: CallDirection
    let timestamp: Date
    let duration: TimeInterval?
    let roomId: String?
    let isSpam: Bool
    
    init(
        contactId: String,
        contactName: String,
        contactPhoneNumber: String,
        contactAvatarURL: String? = nil,
        callType: CallLogType,
        callDirection: CallDirection,
        timestamp: Date,
        duration: TimeInterval? = nil,
        roomId: String? = nil,
        isSpam: Bool = false
    ) {
        self.contactId = contactId
        self.contactName = contactName
        self.contactPhoneNumber = contactPhoneNumber
        self.contactAvatarURL = contactAvatarURL
        self.callType = callType
        self.callDirection = callDirection
        self.timestamp = timestamp
        self.duration = duration
        self.roomId = roomId
        self.isSpam = isSpam
    }
}

enum CallLogType: Codable {
    case voice
    case video
    
    var iconName: String {
        switch self {
        case .voice:
            return "phone.fill"
        case .video:
            return "video.fill"
        }
    }
}

enum CallDirection: Codable {
    case incoming
    case outgoing
    case missed
    case missedOutgoing
    
    var iconName: String {
        switch self {
        case .incoming:
            return "incomingCall"
        case .outgoing:
            return "outgoingCall"
        case .missed:
            return "missedCall"
        case .missedOutgoing:
            return "missedOutgoingCall"
        }
    }
}

extension CallLogEntry {
    
    func formattedTimeOnly(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: date)
    }

    var formattedTime: String {
        
        let timeString = formattedTimeOnly(from: timestamp)
        return timeString
        
//        let now = Date()
//        let timeInterval = now.timeIntervalSince(timestamp)
//        let calendar = Calendar.current
//        
//        if timeInterval < 86400 && calendar.isDateInToday(timestamp) {
//            if timeInterval < 60 {
//                return "Just now"
//            } else if timeInterval < 3600 {
//                let minutes = Int(timeInterval / 60)
//                return "\(minutes) min ago"
//            } else {
//                let hours = Int(timeInterval / 3600)
//                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
//            }
//        } else if calendar.isDateInYesterday(timestamp) {
//            return "Yesterday"
//        } else {
//            let formatter = DateFormatter()
//            formatter.dateStyle = .short
//            return formatter.string(from: timestamp)
//        }
    }
    
    var isGroupCall: Bool {
        return roomId != nil
    }
    
    var callIconName: String {
        if callType == .video {
            return "video_call"
        } else if callType == .voice, callDirection == .missed {
            return "missed_call"
        } else {
            return "audio_call"
        }
    }
    
    var iconName: String {
        if callType == .video, (callDirection == .incoming || callDirection == .missed) {
            return "videocall-incoming"
        } else if callType == .video, (callDirection == .outgoing || callDirection == .missedOutgoing) {
            return "videocall-outgoing"
        } else if callType == .voice, (callDirection == .outgoing || callDirection == .missedOutgoing) {
            return "call-outgoing"
        } else if callType == .voice, (callDirection == .incoming || callDirection == .missed) {
            return "call-incoming"
        } else {
            return "call-incoming"
        }
    }
    
    var callState: String {
        switch callDirection {
        case .incoming: return "Incoming"
        case .missed: return "Incoming"
        case .outgoing: return "Outgoing"
        case .missedOutgoing: return "Outgoing"
        }
    }

    var directionIconName: String {
        switch callDirection {
        case .incoming: return "call_received"
        case .missed: return "call_missed"
        case .outgoing: return "call_made"
        case .missedOutgoing: return "call_missed_outgoing"
        }
    }
}
