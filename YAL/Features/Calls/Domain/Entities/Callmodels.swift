//
//  Callmodels.swift
//  YAL
//
//  Created by Pavithra MH on 16/09/25.
//

import Foundation

enum CallState: Equatable {
    case idle
    case incoming
    case ongoing
    case outgoing
    case decline
    case declineWithMessage
    case end
}

enum CallStatus: String {
    case ringing = "Ringing"
    case answered = "Answered"
    case ended = "Ended"
    case disconnected = "Disconnected"
    case missed = "Missed"
    case busy = "Busy"
    case declined = "Declined"
}

struct LKTokenRequest: Request {
    let roomName:String
    let participantName:String
    let participantId:String
    let avatarUrl:String
}

struct LKTokenResponse: Codable {
    let success:Bool
    let token:String
    let roomName:String
    let participantName:String
    let participantId:String
    let expiresIn:String
}
