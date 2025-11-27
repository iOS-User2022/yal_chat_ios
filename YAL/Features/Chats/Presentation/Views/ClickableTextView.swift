////
////  ClickableTextView.swift
////  YAL
////
//
//import SwiftUI
//
//// In ReceiverMessageView.swift or wherever your message bubble is defined
//struct ReceiverMessageView: View {
//    let message: ChatMessageModel
//    // ... other properties
//    @StateObject private var previewFetcher = URLPreviewFetcher()
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            // Your existing message content
//            // ... existing code ...
//            
//            // Add URL Preview
//            if message.containsURL, let urlString = message.firstURL {
//                if let cachedPreview = URLPreviewCache.shared.getPreview(for: urlString) {
//                    URLPreviewCard(previewData: cachedPreview) {
//                        openURL(urlString)
//                    }
//                    .padding(.top, 4)
//                } else if previewFetcher.isLoading {
//                    HStack {
//                        ProgressView()
//                        Text("Loading preview...")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .frame(height: 60)
//                    .background(Color(.systemGray6))
//                    .cornerRadius(8)
//                } else if let preview = previewFetcher.previewData {
//                    URLPreviewCard(previewData: preview) {
//                        openURL(urlString)
//                    }
//                    .padding(.top, 4)
//                    .onAppear {
//                        URLPreviewCache.shared.setPreview(preview, for: urlString)
//                    }
//                }
//            }
//        }
//        .onAppear {
//            // Fetch preview when message appears
//            if message.containsURL,
//               let urlString = message.firstURL,
//               URLPreviewCache.shared.getPreview(for: urlString) == nil,
//               previewFetcher.previewData == nil {
//                Task {
//                    await previewFetcher.fetchPreview(for: urlString)
//                }
//            }
//        }
//    }
//    
//    private func openURL(_ urlString: String) {
//        if let url = URL(string: urlString) {
//            UIApplication.shared.open(url)
//        }
//    }
//}
// Limit concurrent preview fetches
actor URLPreviewCoordinator {
    static let shared = URLPreviewCoordinator()
    private var activeFetches: Set<String> = []
    private let maxConcurrent = 3
    
    func shouldFetch(url: String) async -> Bool {
        guard activeFetches.count < maxConcurrent else { return false }
        guard !activeFetches.contains(url) else { return false }
        activeFetches.insert(url)
        return true
    }
    
    func completeFetch(url: String) {
        activeFetches.remove(url)
    }
}

// Update URLPreviewFetcher
extension URLPreviewFetcher {
    func fetchPreviewOptimized(for urlString: String) async {
        guard await URLPreviewCoordinator.shared.shouldFetch(url: urlString) else {
            return
        }
        
        defer {
            Task {
                await URLPreviewCoordinator.shared.completeFetch(url: urlString)
            }
        }
        
        await fetchPreview(for: urlString)
    }
}
