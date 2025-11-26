//
//  EmojiStore.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/06/25.
//

import Combine
import Foundation


final class EmojiStore: ObservableObject {
    static let shared = EmojiStore()
    @Published var recents: [Emoji] = []
    var allEmojis: [Emoji] = []

    /// Ordered, unique list of categories (for tabs/paging)
    let categories: [String]
    /// Mapping: category -> [Emoji] (for grid display)
    let emojisByCategory: [String: [Emoji]]

    private init() {
        // Load all emojis from JSON
        if let url = Bundle.main.url(forResource: "emojis", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Emoji].self, from: data) {
            allEmojis = decoded
        } else {
            allEmojis = []
            print("Failed to load emojis from emojis.json")
        }

        // ---- BUILD categories and emojisByCategory ----
         let knownCategories: Set<String> = [
             "Smileys & Emotion",
             "People & Body",
             "Animals & Nature",
             "Food & Drink",
             "Travel & Places",
             "Activities",
             "Objects",
             "Symbols",
             "Flags"
         ]
         var orderedCategories = [String]()
         var seen = Set<String>()
         var byCat = [String: [Emoji]]()
         for emoji in allEmojis {
         let mappedCategory = knownCategories.contains(emoji.category) ? emoji.category : "Food & Drink"
                        if !seen.contains(mappedCategory){
                             orderedCategories.append(mappedCategory)
                             seen.insert(mappedCategory)
                         }
                         byCat[mappedCategory, default: []].append(emoji)
                     }
         self.categories = orderedCategories
         self.emojisByCategory = byCat
         
         // Load recents...
         if let recentEmojis = Storage.get(for: .recentsKey, type: .userDefaults, as: [Emoji].self) {
         recents = recentEmojis
         } else {
         let fallback = allEmojis
         .filter { $0.category == "Smileys & Emotion" }
         .prefix(12)
         recents = Array(fallback.isEmpty ? allEmojis.prefix(7) : fallback)
         }
         }
         
        /*
        let knownCategories: Set<String> = [
            "Smileys & Emotion",
            "People & Body",
            "Animals & Nature",
            "Food & Drink",
            "Travel & Places",
            "Activities",
            "Objects",
            "Symbols",
            "Flags"
        ]
        var orderedCategories = [String]()
        var seen = Set<String>()
        var byCat = [String: [Emoji]]()
         for emoji in allEmojis {
                let mappedCategory = knownCategories.contains(emoji.category) ? emoji.category : "Food & Drink"
                if !seen.contains(mappedCategory){
                    orderedCategories.append(mappedCategory)
                    seen.insert(mappedCategory)
                }
                byCat[mappedCategory, default: []].append(emoji)
            }

        self.categories = orderedCategories
        self.emojisByCategory = byCat
        // Load recents...
        if let recentEmojis = Storage.get(for: .recentsKey, type: .userDefaults, as: [Emoji].self) {
            recents = recentEmojis
        } else {
            let fallback = allEmojis
                .filter { $0.category == "Smileys & Emotion" }
                .prefix(12)
            recents = Array(fallback.isEmpty ? allEmojis.prefix(7) : fallback)
        }
    }
*/
    func addRecent(_ emoji: Emoji) {
        if let index = recents.firstIndex(of: emoji) {
            recents.remove(at: index)
        }
            recents.insert(emoji, at: 0)
            recents = Array(recents.prefix(24))
            Storage.save(recents, for: .recentsKey, type: .userDefaults)
        
    }
}
