//
//  CallKitService.swift
//  YAL
//
//  Created by Pavithra MH on 04/11/25.
//

import PushKit
import CallKit
import SwiftUI

final class CallKitManager: NSObject {
    static let shared = CallKitManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private var isVideo: Bool = false
    var currentUUID:UUID?
    var currentRoomID: String?
    var eventID: String?

    override private init() {
        let config = CXProviderConfiguration(localizedName: "YAL")
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        
        provider = CXProvider(configuration: config)
        
        super.init()
        provider.setDelegate(self, queue: .main)
    }
    
    
    func reportIncomingCall(uuid:UUID, handle: String, roomId: String, isVideo: Bool, eventID: String) {
        self.isVideo = isVideo
        self.currentUUID = uuid
        self.currentRoomID = roomId
        self.eventID = eventID
        
        let update = CXCallUpdate()
        update.localizedCallerName = handle
        update.hasVideo = isVideo
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.supportsDTMF = true
        update.supportsHolding = false
        provider.reportNewIncomingCall(with: self.currentUUID ?? UUID(), update: update) { error in
            if let error = error { print("CallKit incoming error:", error) }
        }
    }
    
    // MARK: - Outgoing call
    func startOutgoingCall(roomId: String, isVideo: Bool = false, completion: (() -> Void)? = nil) {
        if currentUUID == nil {
            currentUUID = UUID()
        }
        currentRoomID = roomId
        let handle = CXHandle(type: .emailAddress, value: roomId)
        let action = CXStartCallAction(call: self.currentUUID ?? UUID(), handle: handle)
        action.isVideo = isVideo
        
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction) {
            // Provide UI update information
            let update = CXCallUpdate()
            update.hasVideo = isVideo
            update.localizedCallerName = "Calling..."
            update.supportsDTMF = false
            
            self.provider.reportCall(with: self.currentUUID ?? UUID(), updated: update)
            self.provider.reportOutgoingCall(with: self.currentUUID ?? UUID(), connectedAt: nil)
            completion?()
        }
    }
    
    func endCall() {
        let action = CXEndCallAction(call: currentUUID ?? UUID())
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction){
            self.provider.reportCall(
                with: action.callUUID,
                endedAt: Date(),
                reason: .unanswered
            )
            self.currentUUID = UUID()
        }
    }
    
    private func requestTransaction(_ transaction: CXTransaction, completion: (() -> Void)? = nil) {
        callController.request(transaction) { error in
            if let error = error {
                print("CallKitManager: \(error.localizedDescription)")
            } else {
                completion?()
            }
        }
    }
    
    func reportCallConnected() {
        provider.reportOutgoingCall(with: self.currentUUID ?? UUID(), connectedAt: Date())
    }
    
    func setMuted(_ isMuted: Bool) {
        let muteAction = CXSetMutedCallAction(call: self.currentUUID ?? UUID(), muted: isMuted)
        let transaction = CXTransaction(action: muteAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("Mute Error:", error.localizedDescription)
            } else {
                print("Mute Action Requested:", isMuted)
            }
        }
    }
    
}

extension CallKitManager: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("Call Answered via CallKit")
        action.fulfill()
        
        guard let roomID = currentRoomID else { return }
        
        let roomModel = DBManager.shared.fetchRoomById(roomId: roomID)?.first ?? RoomModel(lastMessageType: "m.voiceCall", serverTimestamp: 0, lastServerTimestamp: 0)
        
        CallManager.shared.eventId = eventID
        CallManager.shared.isVideoCall = isVideo
        CallManager.shared.presentCall(for: roomModel)
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("Call Ended via CallKit")
        NotificationCenter.default.post(name: .callKitEnded, object: nil)
        action.fulfill()
        provider.reportCall(
            with: action.callUUID,
            endedAt: Date(),
            reason: .unanswered
        )
    }
    
    func provider(_ provider: CXProvider, didEnd call: CXCall) {
        // Only handle our current call UUID
        guard call.uuid == currentUUID else { return }
        
        // When call ends and never connected -> missed
        if call.hasEnded {
            if !call.hasConnected {
                // Missed call detected
                if CallManager.shared.callState == .incoming{
                    CallManager.shared.callState = .idle
                }
            } else {
                // Call connected then ended (normal)
                CallManager.shared.callState = .end
            }
            CallManager.shared.updateCallStatus()

            // cleanup stored state for finished call
            CallManager.shared.endCall()
        }
    }
    func providerDidReset(_ provider: CXProvider) {
        print(" providerDidReset")
    }
}
