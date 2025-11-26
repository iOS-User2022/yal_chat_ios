//
//  UserMappingResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//

import Foundation

// Model to represent the entire response
struct UserMappingResponse: Codable {
    let success: Bool
    let count: Int
    let data: [MappedUser]
}
