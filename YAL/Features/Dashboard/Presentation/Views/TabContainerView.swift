//
//  MainContainerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI
import Combine

enum AppScreen: Hashable {
    case profile
    case appSettings
    case chatDetail(id: String)
}

struct TabContainerView: View {
    @State private var selectedTab: Tab = .sms
    @State private var navPath = NavigationPath()
    @State private var showProfileMenu = false
    @StateObject private var viewModel: TabBarViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var keyboard = KeyboardResponder()
    @EnvironmentObject var router: Router
    @EnvironmentObject var appSettings: AppSettings
    
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }

    init() {
        let viewModel = DIContainer.shared.container.resolve(TabBarViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        
        let profileViewModel = DIContainer.shared.container.resolve(ProfileViewModel.self)!
        _profileViewModel = StateObject(wrappedValue: profileViewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NavigationStack(path: $navPath) {
                    BaseScreenContainer(
                        onMenuTap: {
                            withAnimation {
                                showProfileMenu = true
                            }
                        },
                        onProfileTap: {
                            navPath.append(AppScreen.profile)
                        },
                        bottomBar: {
                            Group {
                                if keyboard.currentHeight == 0 {
                                    VStack(spacing: 0) {
                                        Divider()
                                            .frame(height: 1)
                                            .background(Design.Color.mediumGray)

                                        CustomTabBarView(selectedTab: $selectedTab)
                                            .background(Design.Color.white.opacity(0.95))
                                    }
                                    .padding(.bottom, geometry.safeAreaInsets.bottom + 10)
                                    .background(Design.Color.white)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        },
                        profileViewModel: profileViewModel) {
                            VStack(spacing: 0) {
                                switch selectedTab {
                                case .sms:
                                    SMSListView()
                                case .chats:
                                    RoomListView(navPath: $navPath)
                                case .calls:
                                    CallLogView()
                                case .contacts:
                                    ContactsView()
                            }
                        }
                    }
                    .navigationDestination(for: AppScreen.self) { route in
                        switch route {
                        case .profile:
                            ProfileView(navPath: $navPath)
                                .navigationBarBackButtonHidden(true)
                        case .appSettings:
                            EmptyView()
                        case .chatDetail(_):
                            EmptyView()
                        }
                    }
                }
                //.ignoresSafeArea(.all, edges: .top)
                
                if showProfileMenu {
                    // Slide-in drawer from the left
                    ProfileMenuView(closeAction: {
                        withAnimation {
                            showProfileMenu = false
                        }
                    })
                    //.ignoresSafeArea(.all, edges: .top)
                    .offset(x: showProfileMenu ? 0 : -geometry.size.width)
                    .transition(.move(edge: .leading))
                    .animation(.easeInOut(duration: 0.3), value: showProfileMenu)
                    .zIndex(1)
                }

            }.onAppear() {
                profileViewModel.loadProfile()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .deepLinkOpenChat)
        ) { note in

            guard let type = note.userInfo?["type"] as? String else { return }

            var userInfo: [String: Any] = ["type": type]

            switch type {

            // -----------------------------
            // Conversation
            // -----------------------------
            case DeepLinkType.conversation.rawValue:
                guard let roomId = note.userInfo?["roomId"] as? String else { return }
                userInfo["roomId"] = roomId

            // -----------------------------
            // User Profile inside Conversation
            // -----------------------------
            case DeepLinkType.userProfile.rawValue:
                guard
                    let roomId = note.userInfo?["roomId"] as? String,
                    let userId = note.userInfo?["userId"] as? String
                else { return }
                userInfo["roomId"] = roomId
                userInfo["userId"] = userId

            // -----------------------------
            // Message inside Conversation
            // -----------------------------
            case DeepLinkType.message.rawValue:
                guard
                    let roomId = note.userInfo?["roomId"] as? String,
                    let messageId = note.userInfo?["messageId"] as? String
                else { return }
                userInfo["roomId"] = roomId
                userInfo["messageId"] = messageId

            default:
                return
            }

            // -----------------------------
            // UI resets + routing
            // -----------------------------

            // Close side/profile menu
            if showProfileMenu { showProfileMenu = false }

            // Reset nav stack
            if !navPath.isEmpty {
                navPath.removeLast(navPath.count)
            }

            // Switch to Chats tab
            selectedTab = .chats

            // Delay to ensure tab switch is applied
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(
                    name: .deepLinkOpenChatDetail,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
        .onAppear {
            registerForPushNotificationsIfNeeded()

            LoaderManager.shared.show()
            viewModel.startContactSync {
                LoaderManager.shared.hide()
            }
            
            viewModel.downloadProfile()
            checkForPendingNotificationNavigation()
            DeepLinkManager.shared.triggerPending()
        }
        .onChange(of: router.pendingNotificationNavigation) { newValue in
            if newValue != nil {
                checkForPendingNotificationNavigation()
            }
        }
        .animation(.easeOut(duration: 0.25), value: keyboard.currentHeight)
    }
    
    // MARK: - Permission + Registration

    private func registerForPushNotificationsIfNeeded() {
        if Storage.get(for: .apnsToken, type: .userDefaults, as: String.self) == nil {
            // enqueue the system prompt so it never overlaps other popups
            PromptQueue.enqueue { done in
                requestPushAuthorization(completion: done)
            }
        }
    }
    
    private func requestPushAuthorization(
        provisional: Bool = false,
        openSettingsIfDenied: Bool = false,
        completion: @escaping () -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                var options: UNAuthorizationOptions = [.alert, .badge, .sound]
                if provisional { options.insert(.provisional) }
                
                center.requestAuthorization(options: options) { granted, error in
                    // You can log `granted`/`error` here
                    DispatchQueue.main.async {
                        // You can register even if not granted; token is independent of alert permission
                        UIApplication.shared.registerForRemoteNotifications()
                        completion()
                    }
                }
                
            case .denied:
                // User has explicitly denied; optionally nudge to Settings
                if openSettingsIfDenied {
                    DispatchQueue.main.async {
                        if let url = URL(string: UIApplication.openSettingsURLString),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
                // Still register to obtain APNs token (common pattern)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion()
                }
                
            case .authorized, .provisional, .ephemeral:
                // Already allowed (or quietly allowed): just register
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion()
                }
                
            @unknown default:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    completion() 
                }
            }
        }
    }
    
    // MARK: - Notification Navigation Support
    
    private func checkForPendingNotificationNavigation() {
        guard router.pendingNotificationNavigation != nil else { return }
        
        // Close ProfileMenu if open
        if showProfileMenu {
            showProfileMenu = false
        }
        
        // Clear any navigation within TabContainer
        if !navPath.isEmpty {
            navPath.removeLast(navPath.count)
        }
        
        // Switch to chats tab
        selectedTab = .chats
    }
}


