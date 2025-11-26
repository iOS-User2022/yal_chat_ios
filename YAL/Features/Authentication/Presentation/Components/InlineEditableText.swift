//
//  InlineEditableText.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//

import SwiftUI

struct InlineEditableText: View {
    let maskedPhone: String
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            // Full line text with Edit styled
            Text(buildText())
                .multilineTextAlignment(.center)

            // Tap area positioned over just the word "Edit"
            GeometryReader { geo in
                // Manually position tappable area
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEdit()
                    }
                    .frame(width: 35, height: 24) // Fine-tuned hit area
                    .position(x: geo.size.width - 30, y: geo.size.height / 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
    }

    func buildText() -> AttributedString {
        var full = AttributedString("We are automatically detecting an SMS sent to your mobile number \(maskedPhone) Edit")

        if let editRange = full.range(of: "Edit") {
            full[editRange].foregroundColor = .blue
            full[editRange].underlineStyle = .single
        }

        return full
    }
}
