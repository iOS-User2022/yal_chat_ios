//
//  Emoji.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/06/25.
//


struct Emoji: Codable, Identifiable, Hashable {
    let id: String              // Unicode codepoints as a string, e.g. "1F44B"
    let symbol: String          // The emoji character, e.g. "👋"
    let name: String            // Descriptive name, e.g. "waving hand"
    let category: String        // Main category/group, e.g. "Smileys & Emotion"
    let subcategory: String     // Subcategory/subgroup, e.g. "hand-fingers-open"
    let hasTones: Bool          // True if this emoji supports skin tone variants
    let tones: [EmojiTone]      // Array of all skin tone variants (if any)
}

struct EmojiTone: Codable, Identifiable, Hashable {
    let id: String              // Unicode codepoints of the tone variant, e.g. "1F44B 1F3FB"
    let symbol: String          // The emoji character for the tone variant, e.g. "👋🏻"
    let toneName: String        // Descriptive name, e.g. "waving hand: light skin tone"
}
