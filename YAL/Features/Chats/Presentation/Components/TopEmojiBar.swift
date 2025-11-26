//
//  TopEmojiBar.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/06/25.
//

import SwiftUI

struct TopEmojiBar: View {
    @ObservedObject var emojiStore = EmojiStore.shared
    let onSelect: (Emoji) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojiStore.recents.isEmpty ? emojiStore.allEmojis.prefix(8) : emojiStore.recents.prefix(8)) { emoji in
                    Text(emoji.symbol)
                        .font(.system(size: 28))
                        .onTapGesture {
                            onSelect(emoji)
                            emojiStore.addRecent(emoji)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 52)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
