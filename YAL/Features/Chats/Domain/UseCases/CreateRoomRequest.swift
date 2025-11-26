//
//  CreateRoomRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//

import Foundation
import CryptoKit

// MARK: - CreateRoomRequest Struct
struct CreateRoomRequest: Request {
    let preset: RoomPreset
    var name: String
    let visibility: RoomVisibility
    let invitee: [String]
    let roomVersion: RoomVersion
    var initialState: [RoomMemberState]
    var isDirect: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case preset
        case name
        case visibility
        case invitee
        case roomVersion = "room_version"
        case initialState = "initial_state"
        case isDirect = "is_direct"
    }
    
    // Generate a hashed room name based on invite user IDs
    static func generateHashedRoomName(participants: [String]) -> String {
        let sortedIds = participants.sorted().joined(separator: "_")
        let hashed = SHA256.hash(data: Data(sortedIds.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Initialize room with generated room name
    init(preset: RoomPreset, visibility: RoomVisibility, roomVersion: RoomVersion, invitee: [String], currentUserId: String, roomName: String? = nil, roomDisplayImageUrl: String?) {
        self.preset = preset
        self.visibility = visibility
        self.roomVersion = roomVersion
        self.invitee = invitee
        self.initialState = invitee.map { userId in
            RoomMemberState(
                type: EventType.roomMember.rawValue,
                stateKey: userId,
                content: RoomMemberContent(membership: Membership.invite.rawValue, url: nil)
            )
        }
        // Add the current user with 'join' membership
        let currentUserState = RoomMemberState(
            type: EventType.roomMember.rawValue,
            stateKey: currentUserId,
            content: RoomMemberContent(membership: Membership.join.rawValue, url: nil)
        )
        self.initialState.append(currentUserState)
        
        // Add room avatar state
        if let imageUrl = roomDisplayImageUrl, !imageUrl.isEmpty {
            let avatarState = RoomMemberState(
                type: EventType.roomImage.rawValue,
                stateKey: currentUserId,
                content: RoomMemberContent(membership: nil, url: roomDisplayImageUrl)
            )
            self.initialState.append(avatarState)
        }
        
        // Generate the room name dynamically based on invite user IDs
        self.name = roomName ?? ""
        self.isDirect = invitee.count > 1 ? false : true
    }
}

// MARK: - Initial Room Member State (for each user joining the room)
struct RoomMemberState: Codable {
    let type: String
    let stateKey: String
    let content: RoomMemberContent
    
    enum CodingKeys: String, CodingKey {
        case type
        case stateKey = "state_key"
        case content
    }
}

// MARK: - Content for Room Member (membership join status)
struct RoomMemberContent: Codable {
    let membership: String?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case membership
        case url
    }
}
