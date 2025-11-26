//
//  DeviceInfo.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import UIKit

enum DeviceInfo {
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.echelonera.yalchat"
    }
    
    static var appDisplayName: String {
        // Prefer CFBundleDisplayName, fall back to CFBundleName
        if let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !display.isEmpty {
            return display
        }
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "YAL.ai"
    }
    
    static var deviceDisplayName: String {
        UIDevice.current.name
    }
    
    static var languageCode: String {
        // iOS 16+: Locale has strongly-typed components; keep a wide fallback
        if let id = Locale.preferredLanguages.first {
            let loc = Locale(identifier: id)
            // Try BCP-47 language subtag (e.g., "en", "hi", "en-IN" -> "en")
            if let code = loc.language.languageCode?.identifier {
                return code
            }
        }
        if let code = Locale.current.language.languageCode?.identifier {
            return code
        }
        return "en"
    }
    
    // Optional extras
    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
    
    static var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }
    
    static var systemVersion: String {
        UIDevice.current.systemVersion
    }
    
    static var model: String {
        UIDevice.current.model
    }
    
    static var vendorID: String? {
        UIDevice.current.identifierForVendor?.uuidString
    }
    
    // Short, stable-ish 4-char tag to distinguish devices (optional).
    static var shortProfileTag: String {
        if let id = vendorID {
            // Take last 4 of a simple hash for readability (base36)
            let h = abs(id.hashValue)
            let base36 = String(h, radix: 36, uppercase: false)
            return String(base36.suffix(4))
        }
        return "ios"
    }
}
