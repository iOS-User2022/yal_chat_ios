//
//  YALApp.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI
import FirebaseCore
import Firebase
import netfox
import UserNotifications

@main
struct YALApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container = DIContainer.shared.container
    @StateObject private var envManager: EnvironmentManager
    @StateObject private var appSettings = AppSettings()
    private let authVM: AuthViewModel
    private let router: Router
    
    init () {
        YALApp.initializeFirebase()
        YALApp.handleFreshInstall()
        MediaCacheManager.shared.warmMemoryCacheFromRealm()
        #if DEBUG
        NFX.sharedInstance().start()
        #endif
        
        SettingsRegistrar.registerDefaultsIfNeeded()
        self.authVM = container.resolve(AuthViewModel.self)!
        self.router = container.resolve(Router.self)!
        
        let env = EnvironmentManager()
        env.onChange = { [authVM, router] _, _ in
            YALApp.wipeForEnvironmentChange(authVM: authVM, router: router)
        }
        _envManager = StateObject(wrappedValue: env)
        
        YALApp.warmContactCacheFromDB()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()
                    .edgesIgnoringSafeArea(.all)
                
                RootContainer()
                    .environmentObject(envManager)
                    .environmentObject(router)
                    .environmentObject(container.resolve(AuthViewModel.self)!)
                    .environmentObject(appSettings)
                    .preferredColorScheme(.light)
                    .onAppear {
                        router.currentRoute = .splash
                    }
                    .task {
                        envManager.refresh()
                    }
                    .secureIf(appSettings.disableScreenshot)
                    .onOpenURL { url in
                        DeepLinkManager.shared.handle(url: url)
                    }
            }.ignoresSafeArea(.all)
        }
    }
    
    struct BackgroundView: View {
        var body: some View {
            // Background dim
            Color.black
                .opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("Screenshot Blocked")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                
                Image("Subtract")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.black)
                                
                Text("For your privacy, taking screenshots and screen recordings is disabled.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                HeaderLogo()
                    .padding(.bottom, 42)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .ignoresSafeArea()
            .shadow(radius: 12)
        }
    }
    
    private static func handleFreshInstall() {
        let isFreshInstall = Storage.get(for: .isFreshInstall, type: .userDefaults, as: Bool.self) ?? true
        
        if isFreshInstall {
            Storage.clearAll(type: .keychain)
            Storage.save(false, for: .isFreshInstall, type: .userDefaults)
        }
    }
    
    private static func initializeFirebase() {
        let _ = FirebaseManager.shared
    }
    
    private static func wipeForEnvironmentChange(authVM: AuthViewModel, router: Router) {
        DBManager.shared.clearAllSync(purgeFiles: true)
        Storage.clearAll(type: .keychain)
        Storage.clearAll(type: .userDefaults)
        Storage.clearAll(type: .memory)
        
        // Force logout + route
        DispatchQueue.main.async {
            authVM.logout()
            router.currentRoute = .splash
        }
    }
    
    private static func warmContactCacheFromDB() {
        DispatchQueue.global(qos: .utility).async {
            let contacts = DBManager.shared.fetchContacts() ?? []
            guard !contacts.isEmpty else { return }
            ContactManager.shared.primeCache(with: contacts)
        }
    }
}

extension View {
    @ViewBuilder
    func secureIf(_ enabled: Bool) -> some View {
        if enabled {
            ScreenshotPreventView { self }
        } else {
            EmptyPreventView { self }
        }
    }
}

extension UIApplication {
    var topSafeAreaInset: CGFloat {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }
}
