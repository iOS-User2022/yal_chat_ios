//
//  MatrixUtility.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//

import Foundation

// MARK: - Preset Enum for Room Creation
enum RoomPreset: String, Codable {
    case privateChat = "private_chat"
    case publicChat = "public_chat"
    case trustedPrivateChat = "trusted_private_chat"
    case custom = "custom"
}

// MARK: - Visibility Enum for Room Creation
enum RoomVisibility: String, Codable {
    case private_room = "private"
    case public_room = "public"
    case unlisted_room = "unlisted"
}

// MARK: - Room Version Enum
enum RoomVersion: String, Codable {
    case v1 = "1"
    case v2 = "2"
}

// MARK: - Membership Enum for Room Member State
enum Membership: String, Codable {
    case join = "join"
    case leave = "leave"
    case ban = "ban"
    case invite = "invite"
    case knock = "knock"
}

// MARK: - Event Type Enum for Initial State
enum EventType: String, Codable {
    case roomMember = "m.room.member"
    case roomName = "m.room.name"
    case roomTopic = "m.room.topic"
    case roomHistoryVisibility = "m.room.history_visibility"
    case roomPowerLevels = "m.room.power_levels"
    case roomJoinRules = "m.room.join_rules"
    case roomImage = "m.room.avatar"
}

// MARK: - Join Rule Enum for Room Join Rule
enum JoinRule: String, Codable {
    case publicRule = "public"
    case privateRule = "private"
    case invitedRule = "invite"
}




