//
//  MockAPNsNotificationHelper.swift
//  YAL
//
//  Created by Priyanka Singhnath on 11/11/25.
//

import Foundation
import UserNotifications
import UIKit
import AVFoundation

/// Unified local notification helper using MediaType + MediaCacheManager
final class MockAPNsNotificationHelper {
    
    /// Sends a local notification replicating APNs payload
    static func send(
        title: String,
        body: String,
        mediaType: MediaType,
        mediaURL: String?,
        roomId: String,
        eventId: String,
        senderDisplayName: String
    ) {
        
        
        //  Load preferences
        NotificationSettingsManager.shared.reloadSettings()
        let preferences = NotificationSettingsManager.shared.settings
        
        // Configure notification options based on user preferences
        var options: UNAuthorizationOptions = []
        if preferences.inAppNotificationType == .banners { options.insert(.alert) }
        if preferences.inAppNotificationType == .sounds { options.insert(.sound) }
        options.insert(.badge)
        

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
            guard granted else { return }
            
            // If text or no URL → simple notification
            guard let mediaURL = mediaURL, !mediaURL.isEmpty, (preferences.notificationContentType == .nameAndMessage),
                  (mediaType == .video ||
                   mediaType == .image ||
                   mediaType == .gif) else {
                scheduleNotification(
                    title: title,
                    body: bodyFor(mediaType: mediaType, originalBody: body),
                    roomId: roomId,
                    eventId: eventId,
                    senderDisplayName: senderDisplayName,
                    attachment: nil,
                    contentType: preferences.notificationContentType,
                    groupSound: preferences.groupsSound,
                    msgSound: preferences.messagesSound,
                    soundEnabled: preferences.groupsSoundEnabled
                )
                return
            }
            
            // Fetch media and attach
            MediaCacheManager.shared.getMedia(url: mediaURL, type: mediaType, progressHandler: { _ in }) { result in
                switch result {
                case .success(let localPath):
                    let fileURL = URL(fileURLWithPath: localPath)
                    createAttachment(from: fileURL, type: mediaType) { attachment in
                        scheduleNotification(
                            title: title,
                            body: bodyFor(mediaType: mediaType, originalBody: body),
                            roomId: roomId,
                            eventId: eventId,
                            senderDisplayName: senderDisplayName,
                            attachment: attachment,
                            contentType: preferences.notificationContentType,
                            groupSound: preferences.groupsSound,
                            msgSound: preferences.messagesSound,
                            soundEnabled: preferences.groupsSoundEnabled
                        )
                    }
                    
                case .failure:
                    scheduleNotification(
                        title: title,
                        body: bodyFor(mediaType: mediaType, originalBody: body),
                        roomId: roomId,
                        eventId: eventId,
                        senderDisplayName: senderDisplayName,
                        attachment: nil,
                        contentType: preferences.notificationContentType,
                        groupSound: preferences.groupsSound,
                        msgSound: preferences.messagesSound,
                        soundEnabled: preferences.groupsSoundEnabled
                    )
                }
            }
        }
    }
    
    // MARK: - Create attachment
    
    private static func createAttachment(from fileURL: URL, type: MediaType, completion: @escaping (UNNotificationAttachment?) -> Void) {
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
    
    // MARK: - Body helper
    
    private static func bodyFor(mediaType: MediaType, originalBody: String) -> String {
        switch mediaType {
        case .image: return originalBody == "m.image" ? "📷 Image message" : originalBody
        case .video: return "🎥 Video message"
        case .audio: return "🎧 Audio message"
        case .document: return "📄 Document shared"
        case .gif: return "🌀 GIF"
        }
    }
    
    // MARK: - Schedule
    
    private static func scheduleNotification(
        title: String,
        body: String,
        roomId: String,
        eventId: String,
        senderDisplayName: String,
        attachment: UNNotificationAttachment?,
        contentType: NotificationContentType,
        groupSound: NotificationSoundType,
        msgSound: NotificationSoundType,
        soundEnabled: Bool
    ) {
        
        print("senderDisplayName", senderDisplayName)
        print("title", title)
        print("body", body)

        let content = UNMutableNotificationContent()
        if contentType == .hidden {
            content.title = "New message"
            content.body = ""
        }  else if contentType == .nameOnly {
            content.title = senderDisplayName
            content.body = ""
        } else {
            content.title = "\(title): \(senderDisplayName)"
            content.body = body
        }
        if soundEnabled {
            content.sound = .defaultRingtone
        } else {
            content.sound = .none
        }
        content.categoryIdentifier = "CHAT_CATEGORY"
        content.userInfo = [
            "room_id": roomId,
            "event_id": eventId,
            "sender_display_name": senderDisplayName,
            "local_test_notification": true
        ]
        
        if let attachment = attachment {
            content.attachments = [attachment]
        }
        
        // Trigger after 0.5s so iOS finishes current willPresent cycle
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to add local notification:", error)
            }
        }
    }
}
