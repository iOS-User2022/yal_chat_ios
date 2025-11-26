//
//  AppDelegate.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import UIKit
import UserNotifications
import Combine

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // Resolve from your Swinject container (adjust if you use a different DI access)
    private var apnsStore: APNsTokenStore {
        DIContainer.shared.container.resolve(APNsTokenStore.self)!
    }
    
    private var pushRegistrar: PushRegistrationCoordinator {
        DIContainer.shared.container.resolve(PushRegistrationCoordinator.self)!
    }
    
    private var router: Router {
        DIContainer.shared.container.resolve(Router.self)!
    }
    
    private var chatRepository: ChatRepositoryProtocol {
        DIContainer.shared.container.resolve(ChatRepository.self)!
    }
    
    private var sessionProvider: AuthSessionProvider {
        DIContainer.shared.container.resolve(AuthSessionProvider.self)!
    }
    
    private var cancellables = Set<AnyCancellable>()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories with actions
        registerNotificationCategories()

        // Start the registration orchestration (APNs token + Matrix token)
        pushRegistrar.start()

        return true
    }

    // MARK: - APNs Token Callbacks

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Persist + publish; PushRegistrar will pick it up and call Matrix /pushers/set
        apnsStore.update(deviceToken: deviceToken)
        // No prints needed—keep this silent in production
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Optional: log to your logger/analytics
        print("APNs registration failed: \(error)")
    }

    // MARK: - Foreground notification behavior

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner/list/sound even when app is foreground
        completionHandler([.banner, .list, .sound, .badge])
    }

    // MARK: - User tapped a notification

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different action identifiers
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            // Handle reply action
            if let textResponse = response as? UNTextInputNotificationResponse {
                handleReply(text: textResponse.userText, userInfo: userInfo)
            }
            
        case "MARK_AS_READ_ACTION":
            // Handle mark as read action
            handleMarkAsRead(userInfo: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleNotificationTap(userInfo: userInfo)
            
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            break
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Handle Chat Notification
    
    private func handleChatNotification(roomId: String, eventId: String?) {
        // Fetch room and navigate
        NotificationRouter.fetchRoom(roomId: roomId, chatRepository: chatRepository)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] roomSummaryModel in
                guard let self = self, roomSummaryModel != nil else { return }
                
                // Navigate to dashboard if not already there
                if case .dashboard = self.router.currentRoute {
                    self.router.navigateToChatFromNotification(roomId: roomId, eventId: eventId)
                } else {
                    self.router.currentRoute = .dashboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.router.navigateToChatFromNotification(roomId: roomId, eventId: eventId)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        // Define reply action with text input
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type your message..."
        )
        
        // Define mark as read action
        let markReadAction = UNNotificationAction(
            identifier: "MARK_AS_READ_ACTION",
            title: "Mark as Read",
            options: [] // Can add .authenticationRequired if needed
        )
        
        // Define chat message category with actions
        let chatCategory = UNNotificationCategory(
            identifier: "CHAT_CATEGORY",
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "%u new messages",
            options: []
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([chatCategory])
    }
    
    // MARK: - Notification Action Handlers
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["room_id"] as? String else { return }
        let eventId = userInfo["event_id"] as? String
        handleChatNotification(roomId: roomId, eventId: eventId)
    }
    
    private func handleReply(text: String, userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["room_id"] as? String,
              let userId = sessionProvider.session?.userId else {
            return
        }
        
        let messageModel = ChatMessageModel(
            eventId: UUID().uuidString,
            sender: userId,
            content: text,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            msgType: "m.text",
            userId: userId,
            roomId: roomId,
            messageStatus: .sending
        )
        
        chatRepository.sendMessage(message: messageModel, roomId: roomId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["room_id"] as? String,
              let eventId = userInfo["event_id"] as? String else {
            return
        }
        
        chatRepository.sendReadMarker(
            roomId: roomId,
            fullyReadEventId: eventId,
            readEventId: eventId,
            readPrivateEventId: nil
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] _ in
                guard let self = self else { return }
                UNUserNotificationCenter.current().removeDeliveredNotifications(
                    withIdentifiers: [userInfo["notification_id"] as? String ?? ""]
                )
            }
        )
        .store(in: &cancellables)
    }

    // MARK: - Silent push (content-available:1) — optional but handy

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you use silent pushes to nudge sync, trigger a lightweight refresh here.
        // e.g., MatrixAPIManager.scheduleSyncNudge()
        completionHandler(.noData)
    }
}
