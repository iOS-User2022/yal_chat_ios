//
//  AppRouter.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI
import Combine

final class Router: ObservableObject {
    enum Route {
        case splash
        case login
        case onboarding
        case tutorial
        case dashboard
        case loading
        case chat(userId: String)
        case settings
        case profile
        case faq
        case aboutUs
        case softUpdate
        case forceUpdate
    }
    
    @Published var currentRoute: Route = .splash
    
    // MARK: - Notification Navigation
    
    /// Subject to publish notification navigation events
    let notificationNavigationSubject = PassthroughSubject<NotificationNavigationEvent, Never>()
    
    /// Stores pending notification navigation for when the target view isn't loaded yet
    @Published var pendingNotificationNavigation: NotificationNavigationEvent? = nil
    
    /// Navigate to chat from notification
    func navigateToChatFromNotification(roomId: String, eventId: String?) {
        let event = NotificationNavigationEvent.chat(roomId: roomId, eventId: eventId)
        
        // Try to publish immediately for already-listening subscribers
        notificationNavigationSubject.send(event)
        
        // Also store it in case no one is listening yet (view not loaded)
        pendingNotificationNavigation = event
    }
}

// MARK: - Notification Navigation Event

enum NotificationNavigationEvent: Equatable {
    case chat(roomId: String, eventId: String?)
}
