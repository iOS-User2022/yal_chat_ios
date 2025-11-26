//
//  EmojiCell.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/06/25.
//

import SwiftUI

struct EmojiCell: View {
    let emoji: Emoji
    let onSelect: (String) -> Void
    
    @State private var showTonePicker = false
    
    var body: some View {
        ZStack {
            Button(action: {
                onSelect(emoji.symbol)
            }) {
                Text(emoji.symbol)
                    .font(.system(size: 32))
                    .frame(width: 36, height: 36)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        if emoji.hasTones {
                            showTonePicker = true
                        }
                    }
            )
            
            // Tone picker popup
            if showTonePicker {
                let tones = emoji.tones
                TonePickerPopup(
                    tones: tones,
                    onSelect: { symbol in
                        onSelect(symbol)
                        showTonePicker = false
                    },
                    onDismiss: { showTonePicker = false }
                )
                .offset(y: -54) // Place above the emoji
            }
        }
    }
}
