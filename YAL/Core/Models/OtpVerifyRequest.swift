//
//  OtpVerifyRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct OtpVerifyRequest: Request {
    let mobile: String
    let otp: String
    let deviceId: String
}
