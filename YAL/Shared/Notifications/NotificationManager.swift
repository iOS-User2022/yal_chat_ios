//
//  NotificationManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/04/25.
//


import UserNotifications
import Foundation

enum NotificationManager {
    // MARK: - Request Permission
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("✅ Notification already authorized.")
            case .denied:
                print("⚠️ Notification permission denied.")
            case .notDetermined:
                requestAuthorization()
            @unknown default:
                print("⚠️ Unknown authorization status.")
            }
        }
    }

    private static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Failed to request notification permission: \(error.localizedDescription)")
                return
            }
            if granted {
                print("✅ Notification permission granted.")
            } else {
                print("⚠️ Notification permission not granted by user.")
            }
        }
    }
    
    // MARK: - Send Notification (Spam or Anything)
    static func sendNotification(title: String, body: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("❌ Notifications not allowed, skipping sending.")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Immediate
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error sending notification: \(error.localizedDescription)")
                } else {
                    print("✅ Local notification sent.")
                }
            }
        }
    }
}
