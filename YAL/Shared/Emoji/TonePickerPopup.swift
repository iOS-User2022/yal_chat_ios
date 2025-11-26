//
//  TonePickerPopup.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/06/25.
//

import SwiftUI

struct TonePickerPopup: View {
    let tones: [EmojiTone]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(tones) { tone in
                Button(action: { onSelect(tone.symbol) }) {
                    Text(tone.symbol)
                        .font(.system(size: 32))
                        .padding(4)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
        .shadow(radius: 6)
        .onTapGesture { onDismiss() }
    }
}
