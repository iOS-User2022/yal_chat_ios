//
//  Country.swift
//  YAL
//
//  Created by Vishal Bhadade on 28/04/25.
//

import Foundation

import Foundation

struct Country: Identifiable, Hashable {
    var id: String { code }  // ✅ SwiftUI needs `id`, so use `code` directly.

    let name: String
    let code: String
    let dialCode: String
    let flag: String

    static let allCountries: [Country] = [
        Country(name: "India", code: "IN", dialCode: "+91", flag: "india"),
//        Country(name: "United States", code: "US", dialCode: "+1", flag: "🇺🇸"),
//        Country(name: "United Kingdom", code: "GB", dialCode: "+44", flag: "🇬🇧"),
//        Country(name: "Canada", code: "CA", dialCode: "+1", flag: "🇨🇦"),
//        Country(name: "Australia", code: "AU", dialCode: "+61", flag: "🇦🇺"),
//        Country(name: "Germany", code: "DE", dialCode: "+49", flag: "🇩🇪"),
//        Country(name: "France", code: "FR", dialCode: "+33", flag: "🇫🇷"),
//        Country(name: "Japan", code: "JP", dialCode: "+81", flag: "🇯🇵"),
//        Country(name: "United Arab Emirates", code: "AE", dialCode: "+971", flag: "🇦🇪"),
//        Country(name: "Singapore", code: "SG", dialCode: "+65", flag: "🇸🇬"),
        Country(name: "South Africa", code: "ZA", dialCode: "+27", flag: "south-africa"),
//        Country(name: "Indonesia", code: "ID", dialCode: "+62", flag: "🇮🇩"),
//        Country(name: "Mexico", code: "MX", dialCode: "+52", flag: "🇲🇽"),
        Country(name: "Brazil", code: "BR", dialCode: "+55", flag: "brazil"),
        Country(name: "Russia", code: "RU", dialCode: "+7", flag: "russia"),
//        Country(name: "China", code: "CN", dialCode: "+86", flag: "🇨🇳"),
//        Country(name: "Pakistan", code: "PK", dialCode: "+92", flag: "🇵🇰"),
//        Country(name: "Bangladesh", code: "BD", dialCode: "+880", flag: "🇧🇩"),
//        Country(name: "Sri Lanka", code: "LK", dialCode: "+94", flag: "🇱🇰"),
//        Country(name: "Nepal", code: "NP", dialCode: "+977", flag: "🇳🇵"),
        Country(name: "Sudan", code: "SD", dialCode: "+249", flag: "sudan"),
        Country(name: "Libya", code: "LY", dialCode: "+218", flag: "libya"),
        Country(name: "Spain", code: "ES", dialCode: "+34", flag: "spain")
    ]
}
