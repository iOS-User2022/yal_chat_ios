//
//  PushKitService.swift
//  YAL
//
//  Created by Pavithra MH on 20/11/25.
//

import PushKit
import SwiftUI

final class PushKitManager: NSObject, ObservableObject {
    static let shared = PushKitManager()
    
    private let registry = PKPushRegistry(queue: DispatchQueue.main)
    private var voipStore: VoIPTokenStore {
        DIContainer.shared.container.resolve(VoIPTokenStore.self)!
    }
    override private init() {
        super.init()
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }
    
    func registerForPushKit() {
        registry.delegate = self
    }
}

extension PushKitManager: PKPushRegistryDelegate {
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("VoIP Token = \(token)")
        // send token to server
        voipStore.update(deviceToken: pushCredentials.token)
        
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) {
        let payload = payload.dictionaryPayload
        if let msgType = payload["content_msgtype"] as? String,  (msgType == "m.voiceCall" || msgType == "m.videoCall") {
            
            let eventID = payload["event_id"] as? String ?? ""
            var roomID = payload["room_id"] as? String ?? UUID().uuidString
            let callerName = payload["sender_display_name"] as? String ?? "Yal user"
            let content = payload["content_body"] as? String ?? ""
            
            if content.contains("Invited"){
                let parts = content.split(separator: " ")
                roomID = String(parts[1])
            }
            print("Callmanager ----Pushkit msgType \(msgType)")
            // START CALLKIT UI
            CallKitManager.shared.reportIncomingCall(
                uuid: UUID(),
                handle: callerName,
                roomId: roomID,
                isVideo: (msgType == "m.voiceCall") ? false : true,
                eventID: eventID
            )
            
        }else if let type = payload["type"] as? String, type == "m.call.reject" {
            let content = payload["content_body"] as? String ?? ""
            let parts = content.split(separator: " ")
            var currentUserIDString = ""
            if let val = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)?.userId {
                currentUserIDString = val
            }
            if parts[1] == currentUserIDString {
                CallManager.shared.callState = .end
                CallManager.shared.autoDisconnect()
            }
        }
    }
}
