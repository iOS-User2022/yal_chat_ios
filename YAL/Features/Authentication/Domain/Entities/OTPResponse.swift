//
//  OTPResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/04/25.
//

import Foundation

struct OTPResponse: Codable {
    let success: Bool
    let userID: String
    let accessToken: String
    let homeServer: String
    let deviceID: String
    let token: String
    let refreshToken: String
    let matrixUrl: String?
    let jitsiToken: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case userID = "user_id"
        case accessToken = "access_token"
        case homeServer = "home_server"
        case deviceID = "device_id"
        case token
        case refreshToken
        case matrixUrl = "matrix_url"
        case jitsiToken
    }
}
