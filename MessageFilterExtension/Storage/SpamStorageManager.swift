//
//  SpamStorageManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//


import Foundation

struct SpamStorageManager {
    private static let key = "spamMessages"
    private static let suiteName = "group.yalchat.shared"

    static func save(sender: String, message: String) {
        guard let sharedDefaults = UserDefaults(suiteName: suiteName) else { return }

        var list = sharedDefaults.array(forKey: key) as? [[String: String]] ?? []
        list.append(["sender": sender, "message": message, "date": Date().description])
        sharedDefaults.set(list, forKey: key)
        sharedDefaults.synchronize()

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("spamMessagesUpdated" as CFString),
            nil, nil, true
        )
    }
}
