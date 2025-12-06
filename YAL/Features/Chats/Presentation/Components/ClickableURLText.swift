//
//  ClickableURLText.swift
//  YAL
//
//  Created by Hari krishna on 28/11/25.
//

import SwiftUI

struct ClickableURLText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let searchText: String
    var onURLTapped: (String) -> Void
    
    init(
        text: String,
        fontSize: CGFloat = 14,
        textColor: Color = Design.Color.primaryText,
        searchText: String = "",
        onURLTapped: @escaping (String) -> Void
    ) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
        self.searchText = searchText
        self.onURLTapped = onURLTapped
    }
    
    var body: some View {
        TextViewRepresentable(
            text: text,
            fontSize: fontSize,
            textColor: textColor,
            searchText: searchText,
            onURLTapped: onURLTapped
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TextViewRepresentable: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let searchText: String
    let onURLTapped: (String) -> Void
    
    // Cache attributed string to avoid recreating on every update
    private func getCachedAttributedString() -> NSAttributedString {
        let cacheKey = "\(text)|\(searchText)|\(fontSize)"
        if let cached = attributedStringCache[cacheKey] {
            return cached
        }
        let uiFont = UIFont.systemFont(ofSize: fontSize)
        let attributedString = createAttributedString(
            text: text,
            font: uiFont,
            textColor: UIColor(textColor),
            searchText: searchText
        )
        clearCacheIfNeeded()
        attributedStringCache[cacheKey] = attributedString
        return attributedString
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.isUserInteractionEnabled = true
        textView.dataDetectorTypes = [.link]
        
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        // Set initial attributed text
        textView.attributedText = getCachedAttributedString()
        textView.font = UIFont.systemFont(ofSize: fontSize)
        textView.textColor = UIColor(textColor)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if text or searchText changed
        if uiView.attributedText?.string != text || context.coordinator.lastSearchText != searchText {
            uiView.attributedText = getCachedAttributedString()
            context.coordinator.lastSearchText = searchText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onURLTapped: onURLTapped)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let onURLTapped: (String) -> Void
        var lastSearchText: String = ""
        
        init(onURLTapped: @escaping (String) -> Void) {
            self.onURLTapped = onURLTapped
        }
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            onURLTapped(URL.absoluteString)
            return false
        }
    }
    
    private func createAttributedString(text: String, font: UIFont, textColor: UIColor, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor
            ]
        )
        
        // Highlight search text if provided
        if !searchText.isEmpty {
            let searchRange = (text as NSString).range(of: searchText, options: .caseInsensitive)
            if searchRange.location != NSNotFound {
                attributedString.addAttributes([
                    .backgroundColor: UIColor.yellow.withAlphaComponent(0.3)
                ], range: searchRange)
            }
        }
        
        // Use NSDataDetector directly for better performance - UITextView will handle link styling automatically
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        matches?.forEach { match in
            if let url = match.url {
                // Normalize URL if needed
                var urlString = url.absoluteString
                if urlString.hasPrefix("www.") {
                    urlString = "https://" + urlString
                }
                if let normalizedURL = URL(string: urlString) {
                    attributedString.addAttributes([
                        .link: normalizedURL,
                        .foregroundColor: UIColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: match.range)
                }
            }
        }
        
        return attributedString
    }
}

// Simple cache with size limit to prevent memory issues
private var attributedStringCache: [String: NSAttributedString] = [:]
private let maxCacheSize = 100

private func clearCacheIfNeeded() {
    if attributedStringCache.count > maxCacheSize {
        // Remove oldest entries (simple FIFO)
        let keysToRemove = Array(attributedStringCache.keys.prefix(attributedStringCache.count - maxCacheSize))
        keysToRemove.forEach { attributedStringCache.removeValue(forKey: $0) }
    }
}

