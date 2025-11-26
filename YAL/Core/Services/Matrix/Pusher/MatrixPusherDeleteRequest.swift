//
//  MatrixPusherDeleteRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


struct MatrixPusherDeleteRequest: Codable {
    let appId: String
    let pushkey: String

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case pushkey
    }
}