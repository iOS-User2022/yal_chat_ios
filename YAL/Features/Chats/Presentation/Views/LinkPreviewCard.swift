//
//  URLPreviewModels.swift
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image (if available)
                if let imageURLString = previewData.imageURL,
                   let imageURL = URL(string: imageURLString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 160)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Site name or domain
                    if let siteName = previewData.siteName {
                        Text(siteName.uppercased())
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else if let host = URL(string: previewData.url)?.host {
                        Text(host.uppercased())
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Title
                    if let title = previewData.title {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    // Description
                    if let description = previewData.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    // URL
                    HStack(spacing: 4) {
                        if let favicon = previewData.favicon,
                           let faviconURL = URL(string: favicon) {
                            AsyncImage(url: faviconURL) { image in
                                image
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            } placeholder: {
                                Image(systemName: "globe")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        Text(previewData.url)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
