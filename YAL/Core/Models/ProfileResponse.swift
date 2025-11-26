//
//  ProfileResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct BatchUserProfileResponse: Codable {
    let success: Bool
    let results: [UserProfileResult]
}

struct UserProfileResult: Codable {
    let userID: String
    let found: Bool
    let data: ProfileResponse?
    let error: String?   // Only present if found == false
}

struct ProfileResponse: Codable {
    let _id: String
    let userID: String?
    let name: String?
    let gender: String?
    let about: String?
    let dob: String?
    let profession: String?
    let email: String?
    let phone: String?
    let profilePic: String?
    let mxcProfile: String?
}
