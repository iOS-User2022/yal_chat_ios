//
//  DeepLinkManager.swift
//  YAL
//
//  Created by Priyanka Singhnath on 18/11/25.
//

import SwiftUI

final class DeepLinkManager {
    static let shared = DeepLinkManager()
    var pendingURL: URL?
    
    // MARK: - PUBLIC API
    
    /// Call this after login completes
    func triggerPending() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        process(url)
    }
    
    /// Called from .onOpenURL or AppDelegate continueUserActivity
    func handle(url: URL) {
        DeepLinkAnalytics.log(
            event: "deeplink_received",
            [
                "platform": "iOS",
                "url": url.absoluteString
            ]
        )
        
        pendingURL = url
        process(url)
    }
    
    // MARK: - PROCESSOR
    
    func process(_ url: URL) {
        print("Deep Link Received → \(url.absoluteString)")
        
        // Make sure scheme deep links work
        let rawPath = url.path
        let path = rawPath.split(separator: "/").map { String($0) }
        
        // path example:
        // conversation / {roomID} / user / {userID}
        //
        
        guard path.count > 0 else {
            print("Empty path")
            return
        }
        
        // conversation
        if path[0] == "conversation" {
            handleConversation(path)
            return
        }
        
        print("Unknown deep link:", path)
    }
    
    // MARK: - Conversation Handler
    
    private func handleConversation(_ path: [String]) {
        // path[0] = "conversation"
        // path[1] = roomID
        guard path.count >= 2 else {
            print("Missing roomId")
            return
        }
        
        let roomId = path[1]
        
        // CASE 1: conversation only
        if path.count == 2 {
            postConversation(roomID: roomId)
            return
        }
        
        // CASE 2: conversation + user
        if path.count >= 4, path[2] == "user" {
            let userId = path[3]
            postUser(roomID: roomId, userID: userId)
            return
        }
        
        // CASE 3: conversation + message
        if path.count >= 4, path[2] == "message" {
            let messageId = path[3]
            postMessage(roomID: roomId, messageID: messageId)
            return
        }
        
        print("Unknown conversation path:", path)
    }
    
    // MARK: - POSTERS
    
    private func postConversation(roomID: String) {
        print("Open Conversation:", roomID)
        
        NotificationCenter.default.post(
            name: .deepLinkOpenChat,
            object: nil,
            userInfo: [
                "type": DeepLinkType.conversation.rawValue,
                "roomId": roomID
            ]
        )
    }
    
    private func postUser(roomID: String, userID: String) {
        print("Open User:", userID, "in room:", roomID)
        
        NotificationCenter.default.post(
            name: .deepLinkOpenChat,
            object: nil,
            userInfo: [
                "type": DeepLinkType.userProfile.rawValue,
                "roomId": roomID,
                "userId": userID
            ]
        )
    }
    
    private func postMessage(roomID: String, messageID: String) {
        print("Open Message:", messageID, "in room:", roomID)
        
        NotificationCenter.default.post(
            name: .deepLinkOpenChat,
            object: nil,
            userInfo: [
                "type": DeepLinkType.message.rawValue,
                "roomId": roomID,
                "messageId": messageID
            ]
        )
    }
}

enum DeepLinkType: String {
    case conversation
    case message
    case userProfile
    case unknown
}
