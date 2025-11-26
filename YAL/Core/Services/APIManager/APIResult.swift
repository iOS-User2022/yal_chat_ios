//
//  APIResult.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

enum APIResult<T> {
    case success(T)
    case unsuccess(APIError)
}

struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}
