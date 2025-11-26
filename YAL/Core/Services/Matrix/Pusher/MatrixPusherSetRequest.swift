//
//  MatrixPusherSetRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


struct MatrixPusherSetRequest: Codable {
    // "http" to register, or `nil` to delete via this endpoint
    let kind: String?                // "http" or nil (nil == delete)
    let appId: String                // com.echelonera.yalchat
    let pushkey: String              // APNs token as lowercase hex
    let appDisplayName: String       // "YAL.ai"
    let deviceDisplayName: String    // "Vishal iPhone 12 Pro"
    let profileTag: String           // "" or a short device tag
    let lang: String                 // "en"
    let data: MatrixPusherData
    let append: Bool?                // default: false (replace existing)

    enum CodingKeys: String, CodingKey {
        case kind
        case appId = "app_id"
        case pushkey
        case appDisplayName = "app_display_name"
        case deviceDisplayName = "device_display_name"
        case profileTag = "profile_tag"
        case lang
        case data
        case append
    }
}
