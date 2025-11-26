//
//  EmojiToneFloatingRow.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/06/25.
//

import SwiftUI

struct EmojiToneFloatingRow: View {
    let tones: [EmojiTone]
    let onSelect: (EmojiTone) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tones) { tone in
                Text(tone.symbol)
                    .font(.system(size: 32))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white))
                    .onTapGesture { onSelect(tone) }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemGray6).opacity(0.97))
                .shadow(radius: 4)
        )
    }
}
