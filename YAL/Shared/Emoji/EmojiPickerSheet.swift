//
//  EmojiPickerSheet.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/06/25.
//

import SwiftUI
import Foundation

struct EmojiPickerSheet: View {
    @ObservedObject var emojiStore = EmojiStore.shared
    var onSelect: (Emoji) -> Void
    
    @State private var showingTonePicker: Bool = false
    @State private var toneBaseEmoji: Emoji? = nil
    @State private var toneBaseFrame: CGRect = .zero

    @State private var selectedCategoryIdx: Int = 0
    @Namespace private var tabNamespace
    
    @State private var tonePickerSize: CGSize = .zero

    // For programmatic paging sync (required for precise WhatsApp behavior)
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Emoji Grid Pages (one per category)
                    TabView(selection: $selectedCategoryIdx) {
                        ForEach(Array(emojiStore.categories.enumerated()), id: \.offset) { (idx, cat) in
                            ScrollView {
                                EmojiGrid(
                                    emojis: emojiStore.emojisByCategory[cat] ?? [],
                                    onSelect: { emoji in
                                        onSelect(emoji)
                                        emojiStore.addRecent(emoji)
                                    },
                                    onLongPress: { emoji, frame in
                                        let tones = emoji.tones
                                        if !tones.isEmpty {
                                            toneBaseEmoji = emoji
                                            showingTonePicker = true
                                            toneBaseFrame = frame
                                        }
                                    }
                                )
                                .tag(idx)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .background(Color(.systemBackground))
                    .animation(.easeInOut(duration: 0.16), value: selectedCategoryIdx)
                    
                    Divider().padding(.vertical, 2)
                    
                    // Category Tab Bar (bottom)
                    HStack(spacing: 0) {
                        ForEach(Array(emojiStore.categories.enumerated()), id: \.offset) { (idx, cat) in
                            Button(action: { withAnimation { selectedCategoryIdx = idx } }) {
                                VStack(spacing: 0) {
                                    Text(icon(for: cat))
                                        .font(.system(size: 24))
                                        .opacity(selectedCategoryIdx == idx ? 1 : 0.55)
                                    if selectedCategoryIdx == idx {
                                        Capsule()
                                            .frame(height: 3)
                                            .foregroundColor(.accentColor)
                                            .matchedGeometryEffect(id: "tab", in: tabNamespace)
                                    } else {
                                        Capsule().frame(height: 3).foregroundColor(.clear)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                                .padding(.bottom, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                }
                .background(
                    CustomRoundedCornersShape(radius: 20, roundedCorners: [.topLeft, .topRight])
                        .fill(Design.Color.white)
                )
                
                // Tone Picker (WhatsApp style, placed relative to long-pressed emoji)
                if showingTonePicker, let baseEmoji = toneBaseEmoji {
                    let tones = baseEmoji.tones
                    if !tones.isEmpty {
                        // capture container/global frames *as plain lets* (outside heavy expressions)
                        let containerGlobal = geometry.frame(in: .global)
                        let containerSize = geometry.size

                        // compute center point using helper (pure logic outside ViewBuilder)
                        let pickerCenter = computeTonePickerCenter(
                            containerSize: containerSize,
                            containerGlobal: containerGlobal,
                            emojiGlobalFrame: toneBaseFrame
                        )

                        EmojiToneFloatingRow(
                            tones: tones,
                            onSelect: { tone in
                                let pickedEmoji = Emoji(
                                    id: tone.id,
                                    symbol: tone.symbol,
                                    name: baseEmoji.name,
                                    category: baseEmoji.category,
                                    subcategory: baseEmoji.subcategory,
                                    hasTones: false,
                                    tones: []
                                )
                                onSelect(pickedEmoji)
                                emojiStore.addRecent(pickedEmoji)
                                showingTonePicker = false
                            }
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: ViewSizeKey.self, value: proxy.size)
                            }
                        )
                        .onPreferenceChange(ViewSizeKey.self) { size in
                            tonePickerSize = size
                        }
                        .position(x: pickerCenter.x, y: pickerCenter.y) //  only here
                        .zIndex(10)
                    }
                }
            }
        }
    }

    private func computeTonePickerCenter(containerSize: CGSize,
                                         containerGlobal: CGRect,
                                         emojiGlobalFrame: CGRect) -> CGPoint {
        // convert emoji frame (global) -> local sheet coords
        let emojiLocal = CGRect(
            x: emojiGlobalFrame.minX - containerGlobal.minX,
            y: emojiGlobalFrame.minY - containerGlobal.minY,
            width: emojiGlobalFrame.width,
            height: emojiGlobalFrame.height
        )

        // fallback size until measured
        let fallbackSize = CGSize(width: 240, height: 52)
        let pickerW = tonePickerSize.width > 0 ? tonePickerSize.width : fallbackSize.width
        let pickerH = tonePickerSize.height > 0 ? tonePickerSize.height : fallbackSize.height

        let horizontalPadding: CGFloat = 15
        let verticalPadding: CGFloat = 8
        let gap: CGFloat = 4

        // center X, clamped to keep picker inside sheet
        var posX = emojiLocal.midX
        posX = min(max(posX, pickerW/2 + horizontalPadding),
                   containerSize.width - pickerW/2 - horizontalPadding)

        // Decide above / below
        let canShowAbove = (emojiLocal.minY - gap - pickerH) >= verticalPadding
        let canShowBelow = (emojiLocal.maxY + gap + pickerH) <= (containerSize.height - verticalPadding)

        let aboveCenterY = emojiLocal.minY - gap - pickerH/2
        let belowCenterY = emojiLocal.maxY + gap + pickerH/2

        let posY: CGFloat
        if canShowAbove || !canShowBelow {
            posY = max(aboveCenterY, pickerH/2 + verticalPadding)
        } else {
            posY = min(belowCenterY, containerSize.height - pickerH/2 - verticalPadding)
        }

        return CGPoint(x: posX, y: posY)
    }
    
    func icon(for category: String) -> String {
        switch category {
            case "Recents", "Frequently Used": return "🕘"
            case "Smileys & Emotion": return "😊"
            case "People & Body":     return "🧑"
            case "Animals & Nature":  return "🐻"
            case "Food & Drink":      return "🍔"
            case "Travel & Places":   return "🌇"
            case "Activities":        return "⚽️"
            case "Objects":           return "💡"
            case "Symbols":           return "❤️"
            case "Flags":             return "🏳️"
            default:                  return "🍔"
        }
    }
}


private struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
