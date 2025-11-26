//
//  RoundedShadowModifier.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct RoundedShadowModifier: ViewModifier {
    var cornerRadius: CGFloat = 8
    var shadowRadius: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color(.systemGray2).opacity(0.5),
                    radius: shadowRadius,
                    x: 0,
                    y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}
