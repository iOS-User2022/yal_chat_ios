//
//  EmojiTonePicker.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/06/25.
//

import SwiftUI

struct EmojiTonePicker: View {
    let tones: [String]
    var onSelect: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(tones, id: \.self) { tone in
                Text(tone)
                    .font(.system(size: 32))
                    .padding(4)
                    .onTapGesture {
                        onSelect(tone)
                        onDismiss()
                    }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 8)
        .onTapGesture { onDismiss() }
    }
}
