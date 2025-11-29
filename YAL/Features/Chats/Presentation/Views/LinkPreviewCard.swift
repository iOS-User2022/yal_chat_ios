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
    // Add this conversion method
     func toLinkPreviewData() -> LinkPreviewData {
         return LinkPreviewData(
             url: self.url,
             title: self.title,
             description: self.description,
             imageUrl: self.imageURL,
             siteName: self.siteName,
             favicon: self.favicon
         )
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

// MARK: - URL Preview Card View (UPDATED - Fixed Property Names)
struct URLPreviewCard: View {
    let previewData: URLPreviewData
    var isSender: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Preview Image - FIXED: imageURL instead of imageUrl
                if let imageUrl = previewData.imageURL, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(isSender ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .overlay(
                                    ProgressView()
                                        .tint(isSender ? .white : .gray)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(isSender ? Color.white.opacity(0.2) : Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(isSender ? .white.opacity(0.7) : .gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Preview Text Content
                VStack(alignment: .leading, spacing: 4) {
                    if let title = previewData.title, !title.isEmpty {
                        Text(title)
                            .font(Design.Font.bold(13))
                            .foregroundColor(isSender ? .white : .primary)
                            .lineLimit(2)
                    }
                    
                    if let description = previewData.description, !description.isEmpty {
                        Text(description)
                            .font(Design.Font.regular(11))
                            .foregroundColor(isSender ? .white.opacity(0.8) : .secondary)
                            .lineLimit(2)
                    }
                    
                    // Domain/Site Name
                    if let siteName = previewData.siteName, !siteName.isEmpty {
                        Text(siteName.uppercased())
                            .font(Design.Font.regular(9))
                            .foregroundColor(isSender ? .white.opacity(0.6) : .gray)
                    } else if let host = URL(string: previewData.url)?.host {
                        Text(host.uppercased())
                            .font(Design.Font.regular(9))
                            .foregroundColor(isSender ? .white.opacity(0.6) : .gray)
                    }
                }
                .padding(8)
                .background(isSender ? Color.white.opacity(0.15) : Color.white)
            }
            .background(isSender ? Color.white.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSender ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions for ChatMessageModel
extension ChatMessageModel {
    /// Check if the message content contains a URL
    var containsURL: Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
        return !(matches?.isEmpty ?? true)
    }
    
    /// Extract the first URL from the message content
    var firstURL: String? {
        let urls = URLDetector.extractURLs(from: content)
        return urls.first
    }
    
    /// Extract all URLs from the message content
    var allURLs: [String] {
        return URLDetector.extractURLs(from: content)
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
// URLPreviewData+Extensions.swift

//extension URLPreviewData {
//    /// Converts URLPreviewData to LinkPreviewData
//    func toLinkPreviewData() -> LinkPreviewData {
//        return LinkPreviewData(
//            url: self.url.absoluteString,
//            title: self.title,
//            description: self.description,
//            imageUrl: self.imageURL?.absoluteString,
//            siteName: self.siteName
//        )
//    }
//}

//extension LinkPreviewData {
//    /// Converts LinkPreviewData to URLPreviewData
//    func toURLPreviewData() -> URLPreviewData? {
//        guard let url = URL(string: self.url) else { return nil }
//        
//        return URLPreviewData(
//            url: url,
//            title: self.title,
//            description: self.description,
//            imageURL: self.imageUrl.flatMap { URL(string: $0) },
//            siteName: self.siteName
//        )
//    }
//}
