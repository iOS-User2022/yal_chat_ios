//
//  SettingsRegistrar.swift
//  YAL
//
//  Created by Vishal Bhadade on 19/09/25.
//

import Foundation


final class SettingsRegistrar {
    static func registerDefaultsIfNeeded() {
        guard let url = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
              let dict = NSDictionary(contentsOf: url),
              let prefs = dict["PreferenceSpecifiers"] as? [[String: Any]] else { return }

        var defaults = [String: Any]()
        for item in prefs {
            guard let key = item["Key"] as? String else { continue }
            if let val = item["DefaultValue"] { defaults[key] = val }
        }
        UserDefaults.standard.register(defaults: defaults)
    }
}
