//
//  Response.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

protocol Response: Codable {
    static func parse(from data: Data) -> Self?
}

extension Response {
    static func parse(from data: Data) -> Self? {
        try? JSONDecoder().decode(Self.self, from: data)
    }
}
