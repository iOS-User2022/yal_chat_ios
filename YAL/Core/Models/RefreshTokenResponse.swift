//
//  RefreshTokenResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct RefreshTokenResponse: Response {
    let token: String
    let refreshToken: String
}
