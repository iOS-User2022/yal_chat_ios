//
//  LinkPreviewCard.swift
//  YAL
//
//  Created by Hari krishna on 28/11/25.
//

import Foundation
import SwiftUI

// MARK: - URL Preview Model
struct URLPreviewData: Codable, Identifiable {
    let id = UUID()
    let url: String
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let favicon: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, description, imageURL, siteName, favicon
    }
}

// MARK: - URL Detector
class URLDetector {
    static func extractURLs(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        return matches?.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        } ?? []
    }
    
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

// MARK: - URL Preview Fetcher
class URLPreviewFetcher: ObservableObject {
    @Published var previewData: URLPreviewData?
    @Published var isLoading = false
    
    func fetchPreview(for urlString: String) async {
        guard URLDetector.isValidURL(urlString),
              let url = URL(string: urlString) else {
            return
        }
        
        await MainActor.run { isLoading = true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let htmlString = String(data: data, encoding: .utf8) {
                let preview = parseHTML(htmlString, url: urlString)
                await MainActor.run {
                    self.previewData = preview
                    self.isLoading = false
                }
            }
        } catch {
            print("Failed to fetch URL preview: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func parseHTML(_ html: String, url: String) -> URLPreviewData {
        var title: String?
        var description: String?
        var imageURL: String?
        var siteName: String?
        var favicon: String?
        
        // Extract Open Graph tags
        if let ogTitle = extractMetaContent(from: html, property: "og:title") {
            title = ogTitle
        } else if let titleMatch = html.range(of: "<title>(.*?)</title>", options: .regularExpression) {
            title = String(html[titleMatch]).replacingOccurrences(of: "<title>", with: "").replacingOccurrences(of: "</title>", with: "")
        }
        
        description = extractMetaContent(from: html, property: "og:description")
            ?? extractMetaContent(from: html, name: "description")
        
        imageURL = extractMetaContent(from: html, property: "og:image")
        siteName = extractMetaContent(from: html, property: "og:site_name")
        
        // Extract favicon
        if let faviconMatch = html.range(of: "<link[^>]*rel=[\"'](?:shortcut )?icon[\"'][^>]*href=[\"']([^\"']+)[\"']", options: .regularExpression) {
            let faviconString = String(html[faviconMatch])
            if let hrefRange = faviconString.range(of: "href=[\"']([^\"']+)[\"']", options: .regularExpression) {
                favicon = String(faviconString[hrefRange])
                    .replacingOccurrences(of: "href=\"", with: "")
                    .replacingOccurrences(of: "href='", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
            }
        }
        
        return URLPreviewData(
            url: url,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            imageURL: imageURL,
            siteName: siteName,
            favicon: favicon
        )
    }
    
    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=[\"']\(property)[\"'][^>]*content=[\"']([^\"']*)[\"']"
        if let range = html.range(of: pattern, options: .regularExpression) {
            let metaTag = String(html[range])
            if let contentRange = metaTag.range(of: "content=[\"']([^\"']*)[\"']", options: .regularExpression) {
                return String(metaTag[contentRange])
                    .replacingOccurrences(of: "content=\"", with: "")
                    .replacingOccurrences(of: "content='", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
            }
        }
        return nil
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=[\"']\(name)[\"'][^>]*content=[\"']([^\"']*)[\"']"
        if let range = html.range(of: pattern, options: .regularExpression) {
            let metaTag = String(html[range])
            if let contentRange = metaTag.range(of: "content=[\"']([^\"']*)[\"']", options: .regularExpression) {
                return String(metaTag[contentRange])
                    .replacingOccurrences(of: "content=\"", with: "")
                    .replacingOccurrences(of: "content='", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
            }
        }
        return nil
    }
}

// MARK: - URL Preview Card View
struct URLPreviewCard: View {
    let previewData: URLPreviewData
    let onTap: () -> Void
    
    // Helper to get platform icon based on domain
    private var platformIcon: String? {
        guard let host = URL(string: previewData.url)?.host?.lowercased() else { return nil }
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return "play.rectangle.fill"
        } else if host.contains("twitter.com") || host.contains("x.com") {
            return "at"
        } else if host.contains("instagram.com") {
            return "camera.fill"
        } else if host.contains("facebook.com") {
            return "f.circle.fill"
        }
        return nil
    }
    
    private var displayURL: String {
        guard let url = URL(string: previewData.url) else { return previewData.url }
        if let host = url.host, host.contains("youtube.com") {
            if let videoId = extractYouTubeVideoId(from: previewData.url) {
                return "youtu.be/\(videoId)"
            }
        }
        return url.host ?? previewData.url
    }
    
    private func extractYouTubeVideoId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.contains("youtu.be") == true {
            return String(url.path.dropFirst())
        } else if url.host?.contains("youtube.com") == true {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                return videoId
            }
        }
        return nil
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURLString = previewData.imageURL,
                   let imageURL = URL(string: imageURLString) {
                    GeometryReader { geometry in
                        ZStack(alignment: .center) {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(ProgressView())
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width, height: 141)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            if let host = URL(string: previewData.url)?.host,
                               host.contains("youtube.com") || host.contains("youtu.be") {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .foregroundColor(.black)
                                            .font(.system(size: 24))
                                    )
                            }
                        }
                    }
                    .frame(height: 140)
                    .clipShape(CustomRoundedCornersShape(radius: 8, roundedCorners: [.topLeft, .topRight]))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if let title = previewData.title {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(displayURL)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 4)
                        if let platformIcon = platformIcon {
                            Image(systemName: platformIcon)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions for ChatMessageModel
extension ChatMessageModel {
    var containsURL: Bool {
        !URLDetector.extractURLs(from: content).isEmpty
    }
    
    var firstURL: String? {
        URLDetector.extractURLs(from: content).first
    }
    
    var contentWithoutURLs: String {
        var text = content
        let urls = URLDetector.extractURLs(from: content)
        for url in urls {
            text = text.replacingOccurrences(of: url, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - URL Preview Cache Manager
class URLPreviewCache {
    static let shared = URLPreviewCache()
    private var cache: [String: URLPreviewData] = [:]
    
    func getPreview(for url: String) -> URLPreviewData? {
        return cache[url]
    }
    
    func setPreview(_ preview: URLPreviewData, for url: String) {
        cache[url] = preview
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Usage Example in Message Bubble
struct MessageWithURLPreview: View {
    let message: ChatMessageModel
    @StateObject private var previewFetcher = URLPreviewFetcher()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original message text
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            // URL Preview
            if let urlString = message.firstURL {
                if let cachedPreview = URLPreviewCache.shared.getPreview(for: urlString) {
                    URLPreviewCard(previewData: cachedPreview) {
                        openURL(urlString)
                    }
                } else if previewFetcher.isLoading {
                    ProgressView()
                        .frame(height: 60)
                } else if let preview = previewFetcher.previewData {
                    URLPreviewCard(previewData: preview) {
                        openURL(urlString)
                    }
                    .onAppear {
                        URLPreviewCache.shared.setPreview(preview, for: urlString)
                    }
                }
            }
        }
        .onAppear {
            if let urlString = message.firstURL,
               URLPreviewCache.shared.getPreview(for: urlString) == nil,
               previewFetcher.previewData == nil {
                Task {
                    await previewFetcher.fetchPreview(for: urlString)
                }
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
