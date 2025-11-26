//
//  SpamMessage.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import Foundation

struct SpamMessage: Identifiable {
    var id: String { UUID().uuidString }
    let sender: String
    let message: String
}
