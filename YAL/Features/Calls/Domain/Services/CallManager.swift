//
//  AppRootPresenter.swift
//  YAL
//
//  Created by Pavithra MH on 04/11/25.
//

import SwiftUI
import Combine
import LiveKit
import AudioToolbox

final class CallManager: ObservableObject {
    static let shared = CallManager()
    var lkRoomId: String?
    
    @Published var showCallUI: Bool = false
    @Published var currentRoomModel: RoomModel?
    @Published var callState: CallState = .idle
    @Published var eventId: String?
    @Published var isVideoCall: Bool = false
    @Published var isCallActive: Bool = false
    @Published var showOngoingCallWidget: Bool = false
    @Published var alertModel: AlertViewModel? = nil
    @Published var isSpeakerOn: Bool = false
    @Published var isRingbackPlaying: Bool = false
    @StateObject private var chatViewModel: ChatViewModel

    private var cancellables = Set<AnyCancellable>()
    private let stateQueue = DispatchQueue(label: "com.yal.callstate", qos: .userInitiated)
    
    // 30-second timeout timer
    private var outgoingTimer: Timer?
    private let outgoingTimeout: TimeInterval = 30
    
    private init() {
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: vm)
        setupCallStateListener()
    }
    
    private func setupCallStateListener() {
        NotificationCenter.default.publisher(for: .callStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCallStateNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    func presentCall(for room: RoomModel) {
        currentRoomModel = room
        showCallUI = true
        if callState == .idle{
            callState = .ongoing
        }else if callState != .ongoing && callState != .outgoing {
            callState = .outgoing
            startOutgoingTimeout()
            startRingbackTone()
        }
        isSpeakerOn = isVideoCall
        CallKitManager.shared.startOutgoingCall(roomId: room.id, isVideo: isVideoCall){
            // CallKit UI successfully started
            print("CallManager -- CallKit outgoing triggered")
            
        }
    }

    func endCall() {
        //        DispatchQueue.main.async {
        self.showCallUI = false
        self.currentRoomModel = nil
        self.callState = .end
        self.eventId = nil
        self.isVideoCall = false
        self.isSpeakerOn = false
        CallKitManager.shared.endCall()
        updateCallStatus()
        //        }
        
    }
    func hideCallView() {
        DispatchQueue.main.async {
            self.showCallUI = false
        }
        
    }
    func showIncomingCall(roomModel: RoomModel, lkRoomId: String, eventId: String) {
        DispatchQueue.main.async {
            self.currentRoomModel = roomModel
            self.lkRoomId = lkRoomId
            self.eventId = eventId
            self.showCallUI = true
        }
    }
    
    private func handleCallStateNotification(_ notification: Notification) {
        if let callState = notification.object as? CallState {
            updateCallState(callState, isVideo: false)
        } else if let data = notification.object as? [String: Any],
                  let callState = data["state"] as? CallState,
                  let isVideo = data["isVideo"] as? Bool {
            updateCallState(callState, isVideo: isVideo)
        }
    }
    
    private func updateCallState(_ callState: CallState, isVideo: Bool) {
        updateCallStatus()
    }
    
    func updateCallStatus() {
        print("Callmanager -----------eventid --- \(CallManager.shared.eventId) -- \(CallManager.shared.callState)")
        if CallManager.shared.callState != .outgoing {
            stopRingbackTone()
        }
        if let roomID = CallManager.shared.currentRoomModel?.id, let eventIdVal = CallManager.shared.eventId{
            if let savedMessageModel = DBManager.shared.getMessageIfExists(eventId: eventIdVal) {
                
                savedMessageModel.callStatus = getStatus(CallManager.shared.callState, isVideo: CallManager.shared.isVideoCall)
                let dateFromTimestamp = Date(timeIntervalSince1970: TimeInterval(savedMessageModel.timestamp) / 1000)
                let formatted = dateFromTimestamp.timeAgoShort()
                print("Callmanager -------------------------> dateFromTimestamp.timeAgoShort() \(dateFromTimestamp.timeAgoShort())")
                savedMessageModel.lifetime = formatted
                
                savedMessageModel.content = formatted + " " + callStateToMessageContent(CallManager.shared.callState, isVideo: CallManager.shared.isVideoCall)
                
                DBManager.shared.updateMessage(message: savedMessageModel, inRoom: roomID, inReplyTo: nil)
            }
        }
    }
    
    private func callStateToMessageContent(_ callState: CallState, isVideo: Bool) -> String {
        let callType = isVideo ? "video" : "voice"
        
        switch callState {
            case .incoming:
                return "Incoming \(callType) call"
            case .outgoing:
                return "Ringing"
            case .ongoing:
                return "In-call"
            case .decline:
                return "Declined"
            case .declineWithMessage:
                return "Declined with message"
            case .end:
                return "Ended"
            case .idle:
                return ""
        }
    }

    private func getStatus(_ callState: CallState, isVideo: Bool) -> String {
        let callType = isVideo ? "video" : "voice"
        
        switch callState {
            case .incoming, .outgoing:
                return CallStatus.ringing.rawValue
            case .ongoing:
                return CallStatus.answered.rawValue
            case .decline:
                return CallStatus.declined.rawValue
            case .declineWithMessage:
                return CallStatus.declined.rawValue
            case .end:
                return CallStatus.ended.rawValue
            case .idle:
                return CallStatus.ended.rawValue
        }
    }
    
    private func startOutgoingTimeout() {
        cancelOutgoingTimeout() // avoid duplicates
        
        outgoingTimer = Timer.scheduledTimer(withTimeInterval: outgoingTimeout, repeats: false) { [weak self] _ in
            self?.handleOutgoingTimeout()
        }
    }
    
    private func cancelOutgoingTimeout() {
        stopRingbackTone()
        outgoingTimer?.invalidate()
        outgoingTimer = nil
    }
    
    private func handleOutgoingTimeout() {
        guard callState == .outgoing else { return }
                
        callState = .end

        // notify UI or store missed event if needed
        NotificationCenter.default.post(name: .callStateChanged, object: CallState.end)
        endCall()
        Task {
            await CallSession.shared.disconnectAndClear()
        }
        
    }
    
    func autoDisconnect() {        
        callState = .end
        
        // notify UI or store missed event if needed
        NotificationCenter.default.post(name: .callStateChanged, object: CallState.end)
        endCall()
        Task {
            await CallSession.shared.disconnectAndClear()
        }
        
    }
    func isCallInProgress() -> Bool{
        if callState == .end || callState == .idle || callState == .decline || callState == .declineWithMessage {
            return false
        }else{
            return true
        }
    }
    
    func startRingbackTone() {
        guard !isRingbackPlaying else { return }
        isRingbackPlaying = true
        
        func playLoop() {
//            AudioServicesPlaySystemSoundWithCompletion(1154) { [weak self] in
//                guard let self = self else { return }
//                if isRingbackPlaying {
//                    playLoop()
//                }
//            }
        }
        
        playLoop()
        print("🎵 Ringback started")
    }
    
    func stopRingbackTone() {
        guard isRingbackPlaying else { return }
        isRingbackPlaying = false
        AudioServicesDisposeSystemSoundID(1154)
        print("🔇 Ringback stopped")
    }
}

final class CallSession {
    static let shared = CallSession()
    private init() {}
    
    /// The livekit room held for the app lifetime. Never recreate unless explicitly disconnecting.
    private(set) var room: LiveKit.Room?
    
    /// Attach a room (only used internally)
    func attachRoom(_ room: LiveKit.Room) {
        self.room = room
        room.add(delegate: CallViewModel.shared)
    }
    
    /// Create-or-reuse room instance (safe: if existing room is disconnected create a new one)
    func ensureRoom() -> LiveKit.Room {
        if let r = room {
            // If the existing room is in a terminal/disconnected state, clear and create new
            if r.connectionState == .disconnected {
                // release the old room and create new one
                print("CallSession: existing room is .disconnected → creating new room")
                room = nil
            } else {
                return r
            }
        }
        let r = LiveKit.Room()
        attachRoom(r)
        return r
    }
    
    /// Disconnect and clear
    func disconnectAndClear() async {
        guard let r = room else { return }
        do {
            await r.disconnect()
        } catch {
            print("CallSession.disconnectAndClear error:", error)
        }
        room = nil
    }
}


// MARK: - Notification Extension
extension Notification.Name {
    static let navigateToChat = Notification.Name("navigateToChat")
    static let dismissCallView = Notification.Name("dismissCallView")
}


extension Date {
    func timeAgoShort() -> String {
        let seconds = Int(Date().timeIntervalSince(self))
        
        if seconds < 60 {
            return "\(seconds)s"
        }
        
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        
        let days = hours / 24
        if days < 7 {
            return "\(days)d"
        }
        
        let weeks = days / 7
        if weeks < 4 {
            return "\(weeks)w"
        }
        
        let months = weeks / 4
        if months < 12 {
            return "\(months)mo"
        }
        
        let years = months / 12
        return "\(years)y"
    }
}
