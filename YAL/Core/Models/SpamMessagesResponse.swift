//
//  SpamMessagesResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct SpamMessagesResponse: Response {
    struct SpamMessage: Response {
        let _id: String
        let responseHeader: String
        let message: String
        let createdBy: String
        let createdAt: String
    }

    let spamMessages: [SpamMessage]
}
