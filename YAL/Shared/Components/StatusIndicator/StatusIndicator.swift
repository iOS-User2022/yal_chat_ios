//
//  StatusIndicator.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//


import SwiftUI

struct StatusIndicator: View {
    var color: Color = Design.Color.successGreen
    var size: CGFloat = 12
    var borderColor: Color = Design.Color.white
    var borderWidth: CGFloat = 2

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}
