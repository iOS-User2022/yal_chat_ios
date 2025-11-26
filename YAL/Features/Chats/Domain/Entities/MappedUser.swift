//
//  MappedUser.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//


import Foundation

// Matrix User model representing each user
struct MappedUser: Identifiable, Equatable, Codable {
    var id: String { userId }
    var userId: String
    var phone: String

    enum CodingKeys: String, CodingKey {
        case userId = "userID"
        case phone
    }
    // Conformance to Equatable
    static func == (lhs: MappedUser, rhs: MappedUser) -> Bool {
        return lhs.id == rhs.id && lhs.userId == rhs.userId && lhs.phone == rhs.phone
    }
}
