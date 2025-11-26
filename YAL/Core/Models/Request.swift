//
//  Request.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

protocol Request: Codable {
    var data: Data? { get }
}

extension Request {
    var data: Data? {
        try? JSONEncoder().encode(self)
    }
}
