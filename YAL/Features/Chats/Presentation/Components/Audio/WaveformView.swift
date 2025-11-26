//
//  WaveformView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct WaveformView: View {
    var amplitudes: [CGFloat]
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<amplitudes.count, id: \.self) { index in
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 2, height: max(1, amplitudes[index] * geometry.size.height))
                        .cornerRadius(1)
                }
            }
        }
    }
}
