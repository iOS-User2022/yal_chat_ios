//
//  incomingCallView.swift
//  YAL
//
//  Created by Pavithra MH on 16/10/25.
//
import SwiftUI

struct IncomingCallView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack(spacing: 10) {
                backButton()
                Spacer()
                VStack {
                    Text("Incoming call")
                        .foregroundColor(.green)
                        .font(.headline)
                    Text("End-to-end encrypted")
                        .foregroundColor(.green.opacity(0.8))
                        .font(.caption)
                }
                .padding(15)
                Spacer()
            }
            .padding(.horizontal)
            
            // Caller avatar
            Circle()
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60)
                        .foregroundColor(.white)
                )
            
            // Caller name + call type
            Text(CallManager.shared.currentRoomModel?.name ?? "group")
                .font(.title2).bold()
                .foregroundColor(.white)
            Text(CallManager.shared.isVideoCall ? "YAL video" : "YAL audio")
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            // Animated chevrons
            UpwardChevrons()
                .frame(width: 60)
                .opacity(0.9)
            
            Spacer()
            
            // Call control buttons
            HStack(spacing: 40) {
                // Decline
                Button(action: onDecline) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                }
                
                // Accept (with drag gesture)
                Circle()
                    .fill(Color.green)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
                    .offset(y: dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if gesture.translation.height < 0 {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                if gesture.translation.height < -80 {
                                    onAccept()
                                }
                                withAnimation(.spring()) { dragOffset = .zero }
                            }
                    )
            }
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Back button
    private func backButton() -> some View {
        Button(action: {
            dismiss()
        }) {
            Image("backArrow")
                .foregroundColor(.white)
                .font(.title2)
                .padding(10)
        }
    }
}

// MARK: - Animated Upward Chevrons (decorative)
struct UpwardChevrons: View {
    @State private var animate = false
    private let count = 6
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Image(systemName: "chevron.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .offset(y: animate ? -CGFloat(10 + i*4) : 0)
                    .opacity(animate ? 0.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.9)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.08),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .frame(height: 140)
    }
}
