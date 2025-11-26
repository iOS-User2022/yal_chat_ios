//
//  EnvironmentConfig.swift
//  YAL
//
//  Created by Vishal Bhadade on 19/09/25.
//

import Foundation

enum AppEnvironment: String {
    case dev, uat, prod
}

struct EnvironmentConfig: Equatable {
    let env: AppEnvironment
    let baseURL: URL
    let pushBaseURL: URL

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> EnvironmentConfig {
        let raw = defaults.string(forKey: "app_environment") ?? "prod"
        let env = AppEnvironment(rawValue: raw) ?? .prod

        let base: URL = {
            switch env {
            case .dev:
                if defaults.bool(forKey: "use_custom_base_url"),
                   let s = defaults.string(forKey: "custom_base_url"),
                   let u = URL(string: s), !s.isEmpty {
                    return u
                }
            
                return URL(string: "https://test.yal.chat/api/")!
            case .uat:
                return URL(string: "https://uat.yal.chat/api/")!
            case .prod:
                return URL(string: "https://ai.yal.chat/api/")!
            }
        }()
        
        let pushBase: URL = {
            switch env {
            case .dev:
                return URL(string: "https://push.yal.chat")!
            case .uat:
                return URL(string: "https://push.yal.chat")!
            case .prod:
                return URL(string: "https://push.yal.chat")!
            }
        }()
        
        return .init(env: env, baseURL: base, pushBaseURL: pushBase)
    }
}
