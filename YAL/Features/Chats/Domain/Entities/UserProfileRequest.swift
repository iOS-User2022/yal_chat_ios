//
//  UserProfileRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/06/25.
//

import Foundation

struct UserProfileRequest: Request {
    let userIDs: [String]
}

struct FileUploadRequest: Encodable {
    let file: Data
    let filename: String
    let mimeType: String
}
