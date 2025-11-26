//
//  UploadResponse.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/05/25.
//


/// Represents the response from `POST /_matrix/media/r0/upload`
struct UploadResponse: Decodable {
    /// The MXC URI you use in your `m.image` / `m.video` event
    let contentUri: String

    /// Some servers also include this alias
    let uri: String?

    private enum CodingKeys: String, CodingKey {
        case contentUri = "content_uri"
        case uri
    }
}