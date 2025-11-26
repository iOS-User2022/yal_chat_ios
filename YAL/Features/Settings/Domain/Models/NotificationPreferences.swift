//
//  NotificationPreferences.swift
//  YAL
//
//  Created by Sheetal Jha on 09/10/25.
//

import Foundation

// MARK: - Notification Content Types
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

// MARK: - In-app Notification Types
enum InAppNotificationType: String, CaseIterable, Codable {
    case banners = "banners"
    case sounds = "sounds"
    case vibrate = "vibrate"
    
    var displayName: String {
        switch self {
        case .banners:
            return "Banners"
        case .sounds:
            return "Sounds"
        case .vibrate:
            return "Vibrate"
        }
    }
}

// MARK: - Sound Types
enum NotificationSoundType: String, CaseIterable, Codable {
    case defaultSound = "default"
    case none = "none"
    case custom1 = "custom1"
    case custom2 = "custom2"
    case custom3 = "custom3"
    
    var displayName: String {
        switch self {
        case .defaultSound:
            return "Default"
        case .none:
            return "None"
        case .custom1:
            return "Chime"
        case .custom2:
            return "Bell"
        case .custom3:
            return "Ping"
        }
    }
}

// MARK: - Main Notification Settings Model
struct NotificationPreferences: Codable {
    // Messages Section
    var messagesSoundEnabled: Bool = true
    var messagesSound: NotificationSoundType = .defaultSound
    var messagesReactionNotifications: Bool = true
    
    // Groups Section
    var groupsSoundEnabled: Bool = true
    var groupsSound: NotificationSoundType = .defaultSound
    var groupsReactionNotifications: Bool = true
    
    // Notification Content
    var notificationContentType: NotificationContentType = .nameAndMessage
    
    // Reminders
    var remindersEnabled: Bool = true
    
    // Home Screen Notifications
    var clearBadgeEnabled: Bool = true
    
    // In-app Notifications
    var inAppNotificationType: InAppNotificationType = .banners
    
    // Show Preview
    var showPreview: Bool = true
    
    // MARK: - Storage Keys
    enum StorageKey: String {
        case notificationSettings = "notification_settings"
    }
    
    // MARK: - Default Settings
    static let defaultSettings = NotificationPreferences()
}

// MARK: - Notification Settings Storage Manager
class NotificationSettingsManager: ObservableObject {
    static let shared = NotificationSettingsManager()
    @Published var settings: NotificationPreferences
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        self.settings = Self.loadSettings()
    }
    
    func reloadSettings() {
        settings = Self.loadSettings()
    }
    
    // MARK: - Load Settings
    private static func loadSettings() -> NotificationPreferences {
        let userDefaults = UserDefaults.standard
        
        if let data = userDefaults.data(forKey: NotificationPreferences.StorageKey.notificationSettings.rawValue),
           let settings = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            return settings
        }
        
        return NotificationPreferences.defaultSettings
    }
    
    // MARK: - Save Settings
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: NotificationPreferences.StorageKey.notificationSettings.rawValue)
            userDefaults.synchronize()
        }
    }
    
    // MARK: - Update Methods
    func updateMessagesSoundEnabled(_ enabled: Bool) {
        settings.messagesSoundEnabled = enabled
        saveSettings()
    }
    
    func updateMessagesSound(_ sound: NotificationSoundType) {
        settings.messagesSound = sound
        saveSettings()
    }
    
    func updateMessagesReactionNotifications(_ enabled: Bool) {
        settings.messagesReactionNotifications = enabled
        saveSettings()
    }
    
    func updateGroupsSoundEnabled(_ enabled: Bool) {
        settings.groupsSoundEnabled = enabled
        saveSettings()
    }
    
    func updateGroupsSound(_ sound: NotificationSoundType) {
        settings.groupsSound = sound
        saveSettings()
    }
    
    func updateGroupsReactionNotifications(_ enabled: Bool) {
        settings.groupsReactionNotifications = enabled
        saveSettings()
    }
    
    func updateNotificationContentType(_ type: NotificationContentType) {
        settings.notificationContentType = type
        Storage.save(type, for: .notificationContentType, type: .userDefaults)
        saveSettings()
    }
    
    func updateRemindersEnabled(_ enabled: Bool) {
        settings.remindersEnabled = enabled
        saveSettings()
    }
    
    func updateClearBadgeEnabled(_ enabled: Bool) {
        settings.clearBadgeEnabled = enabled
        saveSettings()
    }
    
    func updateInAppNotificationType(_ type: InAppNotificationType) {
        settings.inAppNotificationType = type
        saveSettings()
    }
    
    func updateShowPreview(_ enabled: Bool) {
        settings.showPreview = enabled
        saveSettings()
    }
}
