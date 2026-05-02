//
//  CallLogService.swift
//  YAL
//
//  Created by Sheetal Jha on 26/09/25.
//

import Foundation
import Combine

protocol CallLogServiceProtocol {
    func addCallLogEntry(from callState: CallState, contactName: String, contactId: String, phoneNumber: String, roomId: String?, isVideo: Bool, isSpam: Bool)
    func addCallLogEntry(from callState: CallState, contactName: String, contactId: String, phoneNumber: String, roomId: String?, isVideo: Bool, isSpam: Bool, timestamp: Date?)
    func getCallLogs() -> [CallLogEntry]
    func clearCallLogs()
}

class CallLogService: CallLogServiceProtocol, ObservableObject {
    static let shared = CallLogService()
    
    @Published var callLogs: [CallLogEntry] = []
    private let userDefaults = UserDefaults.standard
    private let callLogsKey = "YAL_CallLogs"
    
    private init() {
        loadCallLogs()
    }
    
    func addCallLogEntry(from callState: CallState, contactName: String, contactId: String, phoneNumber: String, roomId: String?, isVideo: Bool, isSpam: Bool = false) {
        addCallLogEntry(from: callState, contactName: contactName, contactId: contactId, phoneNumber: phoneNumber, roomId: roomId, isVideo: isVideo, isSpam: isSpam, timestamp: nil)
    }
    
    func addCallLogEntry(from callState: CallState, contactName: String, contactId: String, phoneNumber: String, roomId: String?, isVideo: Bool, isSpam: Bool = false, timestamp: Date? = nil) {
        let direction: CallDirection
        let duration: TimeInterval?
        
        // Mock duration for now
        switch callState {
            case .incoming:
                direction = .incoming
                duration = TimeInterval.random(in: 30...300)
            case .outgoing:
                direction = .outgoing
                duration = TimeInterval.random(in: 15...240)
            case .decline, .declineWithMessage:
                direction = .missed
                duration = nil
            case .ongoing:
                direction = .outgoing
                duration = TimeInterval.random(in: 60...600)
            case .end:
                direction = .outgoing
                duration = TimeInterval.random(in: 30...300)
            case .idle:
                direction = .outgoing
                duration = TimeInterval.random(in: 30...300)
        }
        
        let callLogEntry = CallLogEntry(
            contactId: contactId,
            contactName: contactName,
            contactPhoneNumber: phoneNumber,
            contactAvatarURL: nil,
            callType: isVideo ? .video : .voice,
            callDirection: direction,
            timestamp: timestamp ?? Date(),
            duration: duration,
            roomId: roomId,
            isSpam: isSpam
        )
        
        callLogs.append(callLogEntry)
        // To save call logs to the database — will be used during actual calls
        // saveCallLogs()
    }
    
    func getCallLogs() -> [CallLogEntry] {
        return callLogs
    }
    
    func clearCallLogs() {
        callLogs.removeAll()
        saveCallLogs()
    }
    
    private func loadCallLogs() {
        guard let data = userDefaults.data(forKey: callLogsKey),
              let decodedLogs = try? JSONDecoder().decode([CallLogData].self, from: data) else {
            return
        }
        
        callLogs = decodedLogs.map { data in
            CallLogEntry(
                contactId: data.contactId,
                contactName: data.contactName,
                contactPhoneNumber: data.contactPhoneNumber,
                contactAvatarURL: data.contactAvatarURL,
                callType: data.callType,
                callDirection: data.callDirection,
                timestamp: data.timestamp,
                duration: data.duration,
                roomId: data.roomId,
                isSpam: data.isSpam
            )
        }
    }
    
    private func saveCallLogs() {
        let callLogData = callLogs.map { entry in
            CallLogData(
                contactId: entry.contactId,
                contactName: entry.contactName,
                contactPhoneNumber: entry.contactPhoneNumber,
                contactAvatarURL: entry.contactAvatarURL,
                callType: entry.callType,
                callDirection: entry.callDirection,
                timestamp: entry.timestamp,
                duration: entry.duration,
                roomId: entry.roomId,
                isSpam: entry.isSpam
            )
        }
        
        if let encodedData = try? JSONEncoder().encode(callLogData) {
            userDefaults.set(encodedData, forKey: callLogsKey)
        }
    }
}

// MARK: - Codable Data Model
private struct CallLogData: Codable {
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
}
