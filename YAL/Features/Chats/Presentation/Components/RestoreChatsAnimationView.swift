//
//  RestoreChatsAnimationView.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/11/25.
//


import SwiftUI

struct RestoreChatsAnimationView: View {
    let progress: CGFloat           // 0 ... 1
    let hydratedRooms: Int
    let totalRooms: Int
    
    private let totalDots = 12
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(Color(red: 0.15, green: 0.83, blue: 0.4)) // WhatsApp-ish

            Text("Restoring your chats")
                .font(.system(size: 20, weight: .bold))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("\(hydratedRooms) / \(totalRooms)")
                .font(.footnote)
                .foregroundColor(.secondary)

            // line with icons and dots
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundColor(.gray)

                dotsRow

                Image(systemName: "iphone")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var dotsRow: some View {
        let activeDots = Int(progress * CGFloat(totalDots))
        let pulsingIndex = min(activeDots, totalDots - 1)

        return HStack(spacing: 6) {
            ForEach(0..<totalDots, id: \.self) { idx in
                let isActive = idx < activeDots
                let isPulsing = idx == pulsingIndex && isActive

                Circle()
                    .fill(isActive ?
                          Color(red: 0.15, green: 0.83, blue: 0.4) :
                          Color.gray.opacity(0.25))
                    .frame(width: 10, height: 10)
                    .scaleEffect(isPulsing ? 1.25 : 1.0)
                    .animation(
                        isPulsing
                        ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                        : .default,
                        value: isPulsing
                    )
            }
        }
    }
}
