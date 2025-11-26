//
//  AuthSession.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//


struct AuthSession: Codable {
    let userId: String
    let matrixToken: String
    let homeServer: String
    let deviceId: String
    let accessToken: String
    let refreshToken: String
    let matrixUrl: String
}
