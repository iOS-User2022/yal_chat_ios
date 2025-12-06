//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Priyanka on 13/11/25.
//

import UserNotifications
import UIKit
import UniformTypeIdentifiers
import AVFoundation

enum NotificationContentType: String, CaseIterable, Codable {
    case nameAndMessage = "name_and_message"
    case nameOnly = "name_only"
    case hidden = "hidden"
    
    var displayName: String {
        switch self {
        case .nameAndMessage:
            return "Name & Msg"
        case .nameOnly:
            return "Name only"
        case .hidden:
            return "Hidden"
        }
    }
}

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    func getNotificationContentType() -> NotificationContentType {
        if let type = Storage.get(for: .notificationContentType, type: .userDefaults, as: NotificationContentType.self) {
            return type
        }
        return .nameAndMessage
    }

    // MARK: - Entry Point
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        let contentType = getNotificationContentType()

        let userInfo = content.userInfo
                
        let originalBody = content.body
        let roomId = userInfo["room_id"] as? String ?? ""
        let eventId = userInfo["event_id"] as? String ?? ""
        let senderDisplayName = userInfo["sender_display_name"] as? String ?? ""
        let msgTypeRaw = userInfo["content_msgtype"] as? String ?? "m.text"
        let mediaType = MediaType(rawValue: msgTypeRaw) ?? .text
        let mxcUrlString = userInfo["content_url"] as? String ?? ""
        
        let body = Self.bodyFor(mediaType: mediaType, originalBody: originalBody)
                
        if contentType == .hidden {
            content.title = "New message"
            content.body = ""
        }  else if contentType == .nameOnly {
            content.title = senderDisplayName
            content.body = ""
        } else {
            content.title = "\(content.title): \(senderDisplayName)"
            content.body = body
        }
        
        content.sound = .default
        
        content.userInfo["room_id"] = roomId
        content.userInfo["event_id"] = eventId
        content.userInfo["sender_display_name"] = senderDisplayName
        content.userInfo["local_test_notification"] = true
        

        // If no media URL, deliver immediately
        guard ((!mxcUrlString.isEmpty) && (contentType == .nameAndMessage) && (mediaType == .video ||
                                                                               mediaType == .image ||
                                                                               mediaType == .gif)) else {
            contentHandler(content)
            return
        }

        // Build your API URL for downloading media
        guard let downloadURL = convertMxcToHttpUrl(mxcUrlString) else {
            print("Invalid download URL")
            contentHandler(content)
            return
        }
        
        print("downloadURLdownloadURLdownloadURL", downloadURL)

        // Download before showing notification
        downloadFile(from: downloadURL, mediaType: mediaType) { localURL in
            if let fileURL = localURL {
                self.createAttachment(from: fileURL, type: mediaType) { attachment in
                    if let attachment = attachment {
                        content.attachments = [attachment]
                        self.contentHandler?(content)
                    }
                }
            }
        }
    }
    
    public func convertMxcToHttpUrl(_ mxcUrl: String) -> URL? {
        let cleanUrl = mxcUrl.hasPrefix("@") ? String(mxcUrl.dropFirst()) : mxcUrl
        guard cleanUrl.starts(with: "mxc://") else { return nil }
        
        let parts = cleanUrl.dropFirst("mxc://".count).split(separator: "/")
        guard parts.count == 2 else { return nil }
        
        let serverName = String(parts[0])
        let mediaId = String(parts[1])
        let homeserver = "https://ai.yal.chat"
        
        return URL(string: "\(homeserver)/_matrix/client/v1/media/download/\(serverName)/\(mediaId)")
    }
    
    // Helper method to create an attachment from the image URL
    private func createImageAttachment(from filePath: String) -> UNNotificationAttachment? {
        let fileManager = FileManager.default

        // Check if the file exists at the specified path
        guard fileManager.fileExists(atPath: filePath) else {
            print("File does not exist at path:", filePath)
            return nil
        }

        // Convert the file path to URL
        let fileURL = URL(fileURLWithPath: filePath)

        // Attempt to create an attachment
        do {
            // Create the attachment with the image
            let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: fileURL, options: nil)
            print("📎 Attachment created:", attachment)
            return attachment
        } catch {
            print("Failed to create attachment:", error)
            return nil
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }

    // MARK: - Download Helper
    private func downloadFile(from url: URL,
                              mediaType: MediaType,
                              completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = Storage.get(for: .matrixToken, type: .userDefaults, as: String.self) ?? ""
        
        print(token)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            
            let mimeType = response?.mimeType ?? ""
            print("Downloaded MIME type:", mimeType)

            guard let tempURL = tempURL, error == nil else {
                print("Download failed:", error?.localizedDescription ?? "unknown")
                completion(nil)
                return
            }

            // Move the file to a temp URL with proper extension
            let fileManager = FileManager.default
            let localURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + mediaType.fileExtension)

            do {
                try fileManager.moveItem(at: tempURL, to: localURL)

                // Validate the file size (optional)
                let data = try Data(contentsOf: localURL)
                guard data.count > 100 else {
                    print("Downloaded file is too small, likely invalid media")
                    completion(nil)
                    return
                }

                print("Media downloaded to:", localURL.path, "size:", data.count)
                completion(localURL)
            } catch {
                print("Failed to move downloaded file:", error)
                completion(nil)
            }
        }

        task.resume()
    }
    
    private func createAttachment(from fileURL: URL, type: MediaType, completion: @escaping (UNNotificationAttachment?) -> Void) {
        switch type {
        case .image, .gif:
            let attachment = try? UNNotificationAttachment(identifier: "image", url: fileURL)
            completion(attachment)
            
        case .video:
            DispatchQueue.global(qos: .background).async {
                let asset = AVAsset(url: fileURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 1, preferredTimescale: 60)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
                    if let data = thumbnail.jpegData(compressionQuality: 0.8) {
                        try data.write(to: tmpURL)
                        let attachment = try? UNNotificationAttachment(identifier: "video_thumb", url: tmpURL)
                        completion(attachment)
                    } else {
                        completion(nil)
                    }
                } catch {
                    completion(nil)
                }
            }
            
        default:
            completion(nil)
        }
    }

    // MARK: - Dummy UIImage Placeholder
    private func saveUIImagePlaceholder(for mediaType: MediaType) -> URL? {
        let symbolName: String
        switch mediaType {
        case .image: symbolName = "photo"
        case .video: symbolName = "video.fill"
        case .audio: symbolName = "waveform"
        case .document: symbolName = "doc.text"
        case .gif: symbolName = "sparkles"
        case .text: symbolName = "text.bubble"
        }
        
        guard let systemImage = UIImage(systemName: symbolName)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal) else {
            return nil
        }
        
        guard let data = systemImage.pngData() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dummy-\(UUID().uuidString).png")
        try? data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Body Customization
    private static func bodyFor(mediaType: MediaType, originalBody: String) -> String {
        switch mediaType {
        case .image: return originalBody == "m.image" ? "📷 Image" : originalBody
        case .video: return "🎥 Video"
        case .audio: return "🎧 Audio"
        case .document: return "📄 Document"
        case .gif: return "🌀 GIF"
        case .text: return originalBody
        }
    }
}

// MARK: - MediaType Enum
enum MediaType: String {
    case text = "m.text"
    case image = "m.image"
    case video = "m.video"
    case audio = "m.audio"
    case document = "m.file"
    case gif = "m.gif"

    var fileExtension: String {
        switch self {
        case .image: return "jpg"
        case .video: return "mp4"
        case .audio: return "m4a"
        case .document: return "pdf"
        case .gif: return "gif"
        case .text: return "txt"
        }
    }
}
