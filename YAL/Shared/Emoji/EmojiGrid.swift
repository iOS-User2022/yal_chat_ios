//
//  EmojiGrid.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/06/25.
//

import SwiftUI

// PreferenceKey for passing frame up from each emoji cell
struct EmojiCellFrameKey: PreferenceKey {
    static var defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let new = nextValue() { value = new }
    }
}

// Emoji grid
struct EmojiGrid: View {
    var emojis: [Emoji]
    var onSelect: (Emoji) -> Void
    var onLongPress: (Emoji, CGRect) -> Void  // Now sends frame

    let columns = Array(repeating: GridItem(.flexible()), count: 8)

    @State private var currentEmojiId: String?
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(emojis) { emoji in
                Text(emoji.symbol)
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: EmojiCellFrameKey.self,
                                    value: currentEmojiId == emoji.id ? geo.frame(in: .global) : nil
                                )
                        }
                    )
                    .onTapGesture { onSelect(emoji) }
                    .onLongPressGesture {
                        currentEmojiId = emoji.id
                    }
            }
        }
        .onPreferenceChange(EmojiCellFrameKey.self) { frame in
            if let id = currentEmojiId, let emoji = emojis.first(where: { $0.id == id }), let frame = frame {
                onLongPress(emoji, frame)
                currentEmojiId = nil
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
