//
//  UnderlinedButtonStyle.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct UnderlinedButtonStyle: ViewModifier {
    var font: Font = .body

    func body(content: Content) -> some View {
        content
            .font(font)
            .underline()
    }
}
