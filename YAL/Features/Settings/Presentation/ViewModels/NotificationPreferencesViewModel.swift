//
//  NotificationPreferencesViewModel.swift
//  YAL
//
//  Created by Sheetal Jha on 09/10/25.
//

import SwiftUI
import Combine

class NotificationPreferencesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var settingsManager = NotificationSettingsManager()
    @Published var showSoundPicker = false
    @Published var currentSoundPickerType: SoundPickerType = .messages
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Sound Picker Type
    enum SoundPickerType {
        case messages
        case groups
    }
    
    init() {
        // Listen to settings changes
        settingsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Actions
    func showMessagesSoundPicker() {
        currentSoundPickerType = .messages
        showSoundPicker = true
    }
    
    func showGroupsSoundPicker() {
        currentSoundPickerType = .groups
        showSoundPicker = true
    }
    
    // MARK: - Sound Selection
    func selectSound(_ sound: NotificationSoundType) {
        switch currentSoundPickerType {
        case .messages:
            settingsManager.updateMessagesSound(sound)
        case .groups:
            settingsManager.updateGroupsSound(sound)
        }
        showSoundPicker = false
    }
    
    // MARK: - Toggle Actions
    func toggleMessagesSoundEnabled() {
        let newValue = !settingsManager.settings.messagesSoundEnabled
        settingsManager.updateMessagesSoundEnabled(newValue)
        
        // If disabling sound, also disable reaction notifications
        if !newValue {
            settingsManager.updateMessagesReactionNotifications(false)
        }
    }
    
    func toggleMessagesReactionNotifications() {
        let newValue = !settingsManager.settings.messagesReactionNotifications
        settingsManager.updateMessagesReactionNotifications(newValue)
    }
    
    func toggleGroupsSoundEnabled() {
        let newValue = !settingsManager.settings.groupsSoundEnabled
        settingsManager.updateGroupsSoundEnabled(newValue)
        
        // If disabling sound, also disable reaction notifications
        if !newValue {
            settingsManager.updateGroupsReactionNotifications(false)
        }
    }
    
    func toggleGroupsReactionNotifications() {
        let newValue = !settingsManager.settings.groupsReactionNotifications
        settingsManager.updateGroupsReactionNotifications(newValue)
    }
    
    func toggleReminders() {
        let newValue = !settingsManager.settings.remindersEnabled
        settingsManager.updateRemindersEnabled(newValue)
    }
    
    func toggleClearBadge() {
        let newValue = !settingsManager.settings.clearBadgeEnabled
        settingsManager.updateClearBadgeEnabled(newValue)
    }
    
    func toggleShowPreview() {
        let newValue = !settingsManager.settings.showPreview
        settingsManager.updateShowPreview(newValue)
    }
    
    // MARK: - Selection Actions
    func selectNotificationContentType(_ type: NotificationContentType) {
        settingsManager.updateNotificationContentType(type)
    }
    
    func selectInAppNotificationType(_ type: InAppNotificationType) {
        settingsManager.updateInAppNotificationType(type)
    }
    
    // MARK: - Computed Properties
    var isMessagesReactionEnabled: Bool {
        settingsManager.settings.messagesSoundEnabled && settingsManager.settings.messagesReactionNotifications
    }
    
    var isGroupsReactionEnabled: Bool {
        settingsManager.settings.groupsSoundEnabled && settingsManager.settings.groupsReactionNotifications
    }
    
    var currentMessagesSound: NotificationSoundType {
        settingsManager.settings.messagesSound
    }
    
    var currentGroupsSound: NotificationSoundType {
        settingsManager.settings.groupsSound
    }
    
    var currentNotificationContentType: NotificationContentType {
        settingsManager.settings.notificationContentType
    }
    
    var currentInAppNotificationType: InAppNotificationType {
        settingsManager.settings.inAppNotificationType
    }
}
