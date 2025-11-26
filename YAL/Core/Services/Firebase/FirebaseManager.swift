//
//  FirebaseManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 01/05/25.
//


import Foundation
import FirebaseCore
import FirebaseRemoteConfig
import FirebaseAnalytics

final class FirebaseManager {
    static let shared = FirebaseManager()
    
    var appStoreURL: URL? {
        let urlString = remoteConfig["ios_app_store_url"].stringValue
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    private init() {
        FirebaseApp.configure()
        remoteConfig = RemoteConfig.remoteConfig()
        
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
    }
    
    private let remoteConfig: RemoteConfig
    
    func fetchConfig(completion: @escaping (_ needsUpdate: Bool, _ isForce: Bool) -> Void) {
        remoteConfig.fetchAndActivate { status, _ in
            guard status != .error else {
                print("❌ Firebase RemoteConfig fetch failed")
                completion(false, false)
                return
            }
            
            let latestVersion = self.remoteConfig["ios_latest_version"].stringValue
            let forceUpdate = self.remoteConfig["ios_force_update"].boolValue
            
            let screenshot_block_enabled = self.remoteConfig["screenshot_block_enabled"].boolValue
            Storage.save(screenshot_block_enabled, for: .screenshotEnabled, type: .userDefaults)

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            
            let needsUpdate = currentVersion.compare(latestVersion, options: .numeric) == .orderedAscending
            completion(needsUpdate, forceUpdate)
        }
    }
}

struct DeepLinkAnalytics {

    static func log(
        event name: String,
        _ params: [String: Any]? = nil
    ) {
        Analytics.logEvent(name, parameters: params)
    }
}
