//
//  VerifyResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct VerifyResponse: Response {
    let success: String
    let token: String
    let refreshToken: String
}
