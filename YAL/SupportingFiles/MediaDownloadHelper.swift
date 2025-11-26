//
//  MediaDownloadHelper.swift
//  YAL
//
//  Created by Sheetal Jha on 28/10/25.
//

import Foundation

public final class MediaDownloadHelper {
    
    // MARK: - App Group Configuration
    
    private static let appGroupIdentifier = "group.yalchat.share"
    private static let tokenKey = "matrix_access_token"
    
    // MARK: - Token Management
    
    public static func saveToken(_ token: String) {
        UserDefaults(suiteName: appGroupIdentifier)?.set(token, forKey: tokenKey)
        UserDefaults(suiteName: appGroupIdentifier)?.synchronize()
    }
    
    public static func clearToken() {
        UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: tokenKey)
        UserDefaults(suiteName: appGroupIdentifier)?.synchronize()
    }
    
    private static func getToken() -> String? {
        UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: tokenKey)
    }
    
    // MARK: - MXC URL Conversion
    
    /// Convert Matrix MXC URL to HTTP download URL
    public static func convertMxcToHttpUrl(_ mxcUrl: String) -> URL? {
        let cleanUrl = mxcUrl.hasPrefix("@") ? String(mxcUrl.dropFirst()) : mxcUrl
        guard cleanUrl.starts(with: "mxc://") else { return nil }
        
        let parts = cleanUrl.dropFirst("mxc://".count).split(separator: "/")
        guard parts.count == 2 else { return nil }
        
        let serverName = String(parts[0])
        let mediaId = String(parts[1])
        let homeserver = "https://ai.yal.chat"
        
        return URL(string: "\(homeserver)/_matrix/client/v1/media/download/\(serverName)/\(mediaId)")
    }
    
    // MARK: - Download with Authentication
    
    /// Download media from URL with optional authentication
    public static func downloadMedia(
        from url: URL,
        useAuth: Bool = true,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authentication header if requested and available
        if useAuth, let token = getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let error = NSError(
                    domain: "MediaDownloadHelper",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
                )
                completion(.failure(error))
                return
            }
            
            guard let localURL = localURL else {
                let error = NSError(
                    domain: "MediaDownloadHelper",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No local URL returned"]
                )
                completion(.failure(error))
                return
            }
            
            completion(.success(localURL))
        }
        
        task.resume()
    }
    
    /// Download media from MXC URL with authentication
    public static func downloadFromMxc(
        _ mxcUrl: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let httpUrl = convertMxcToHttpUrl(mxcUrl) else {
            let error = NSError(
                domain: "MediaDownloadHelper",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid MXC URL"]
            )
            completion(.failure(error))
            return
        }
        
        downloadMedia(from: httpUrl, useAuth: true, completion: completion)
    }
}

