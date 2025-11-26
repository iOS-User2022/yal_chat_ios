//
//  SaveMessageRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct SaveMessageRequest: Request {
    let responseHeader: String
    let message: String
}
