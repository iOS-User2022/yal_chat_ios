//
//  MatrixAPIEndpoints.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import Foundation

/// Enum for Matrix API Endpoints
enum MatrixAPIEndpoints: String {
    // Base URL for Matrix
    
    // Endpoint cases
    case login = "/_matrix/client/v3/login"
    case logout = "/_matrix/client/v3/logout"
    case sync = "/_matrix/client/v3/sync"
    case joinedRooms = "/_matrix/client/v3/joined_rooms"
    case sendMessage = "/_matrix/client/v3/rooms/{roomId}/send/{eventType}/{txnId}"
    case register = "/_matrix/client/v3/register"
    case profile = "/_matrix/client/v3/account/whoami"
    case updateProfile = "/_matrix/client/v3/account/updates"
    
    // More endpoints
    case getPresignedUrl = "/_matrix/client/v3/upload/presigned_url"
    case getMessages = "/_matrix/client/v3/rooms/{roomId}/messages"
    
    // Additional endpoints
    case getRoomState = "/_matrix/client/v3/rooms/{roomId}/state"
    case joinRoom = "/_matrix/client/v3/rooms/{roomId}/join"
    case leaveRoom = "/_matrix/client/v3/rooms/{roomId}/leave"
    case forgetRoom = "/_matrix/client/v3/rooms/{roomId}/forget"
    case createRoom = "/_matrix/client/v3/createRoom"
    case inviteToRoom = "/_matrix/client/v3/rooms/{roomId}/invite"
    case kickFromRoom = "/_matrix/client/v3/rooms/{roomId}/kick"
    case banFromRoom = "/_matrix/client/v3/rooms/{roomId}/ban"
    case unbanFromRoom = "/_matrix/client/v3/rooms/{roomId}/unban"
    case uploadMedia = "/_matrix/media/v3/upload"
    case downloadMedia = "/_matrix/client/v1/media/download/{serverName}/{mediaId}"
    case sendReceipt = "/_matrix/client/v3/rooms/{roomId}/read_markers"
    case typing = "/_matrix/client/v3/rooms/{roomId}/typing/{userId}"
    case redact = "/_matrix/client/v3/rooms/{roomId}/redact/{eventId}/{txnId}"
    case reaction = "/_matrix/client/v3/rooms/{roomId}/send/m.reaction/{txnId}"
    case members = "/_matrix/client/v3/rooms/{roomId}/members"
    case updateRoomName = "/_matrix/client/v3/rooms/{roomId}/state/m.room.name"
    case updateRoomImage = "/_matrix/client/v3/rooms/{roomId}/state/m.room.avatar"
    case pushersSet = "/_matrix/client/v3/pushers/set"
    case pusherDelete = "/_matrix/client/v3/pushers/delete"
    case pusherUrl = "/_matrix/push/v1/notify"
    case roomPushRule = "/_matrix/client/v3/pushrules/global/room/{roomId}"

    // Add additional endpoints as necessary
    
    // MARK: - Helper methods
    
    /// Generate the full URL string for an endpoint
    func urlString(withPathParameters parameters: [String: String]? = nil) -> String {
        var path = self.rawValue
        parameters?.forEach { key, value in
            path = path.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        // SPECIAL-CASE: the push gateway lives on pushBaseURL, not the Matrix homeserver
        if self == .pusherUrl {
            // Ensure we return: <pushBaseURL>/_matrix/push/v1/notify
            let base = EnvironmentConfig.fromDefaults().pushBaseURL
            // self.rawValue for .pusherUrl is "/_matrix/push/v1/notify"
            return base.appendingPathComponent(
                path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            ).absoluteString
        }
        
        // Default: Matrix endpoints use the homeserver base from the stored session
        if let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            return authSession.matrixUrl + path
        }
        
        // Fallback (rare): if no session yet, you can optionally point Matrix to an env HS.
        // If you have a matrixBaseURL in your env, prefer using that here.
        return ""
    }
}
