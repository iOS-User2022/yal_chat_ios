//
//  WebViewScreen.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import WebKit

struct WebViewScreen: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = WebViewModel()
    @State private var webViewRef: WKWebView?
    @State private var currentURL: URL?
    @State private var displayURL: String = ""
    
    init(urlString: String) {
        self.urlString = urlString
    }
    
    var body: some View {
        ZStack {
            // Background - match other screens
            Design.Color.chatBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                browserHeader
                
                // Content Area
                if viewModel.error != nil {
                    errorView
                } else {
                    webViewContent
                }
            }
            
            // Bottom "Open in browser" button - positioned at bottom with elevation
            if viewModel.error == nil {
                VStack {
                    Spacer()
                    openInBrowserButton
                }
            }
        }
        .onAppear {
            setupWebView()
        }
        .onDisappear {
            clearWebData()
        }
    }
    
    // MARK: - Browser Header
    private var browserHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Back button
                Button(action: {
                    if viewModel.canGoBack, let webView = webViewRef {
                        webView.goBack()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Design.Color.primaryText)
                        .frame(width: 44, height: 44)
                }
                .opacity(viewModel.canGoBack ? 1.0 : 0.5)
                
                Spacer()
                
                // Title and URL
                VStack(spacing: 2) {
                    Text("YAL. ai Browser")
                        .font(Design.Font.bold(16))
                        .foregroundColor(Design.Color.primaryText)
                    
                    Text(displayURL.isEmpty ? normalizeURL(urlString) : displayURL)
                        .font(Design.Font.regular(12))
                        .foregroundColor(Design.Color.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Design.Color.primaryText)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Design.Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - WebView Content
    private var webViewContent: some View {
        ZStack {
            if let url = currentURL {
                InAppWebView(
                    url: url,
                    viewModel: viewModel,
                    webViewRef: $webViewRef,
                    onURLChange: { url in
                        updateDisplayURL(url)
                    }
                )
            } else {
                Design.Color.chatBackground
            }
            
            // Loading indicator
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Design.Color.blue))
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Design.Color.chatBackground.opacity(0.8))
            }
        }
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 75) {
            
            // Error message
            Text("Page failed to load")
                .font(Design.Font.semiBold(32))
                .foregroundColor(Design.Color.primaryText)
            
            // Robot icon - custom image
            Group {
                if let robotImage = UIImage(named: "robotIcon") {
                    Image(uiImage: robotImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 150)
                }
            }
            .padding(.top, 8)
            
            // Action buttons
            VStack(spacing: 12) {
                // Reload button - improved with gradient and elevation
                Button(action: {
                    reloadPage()
                }) {
                    Text("Reload")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(.white)
                        .frame(width: 290, height: 60)
                        .background(Design.Color.appGradient)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                // Open in browser button
                Button(action: {
                    openInSafari()
                }) {
                    Text("Open in browser")
                        .font(Design.Font.semiBold(16))
                        .foregroundColor(Design.Color.blue)
                        .frame(width: 290, height: 60)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Design.Color.blue, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Design.Color.chatBackground)
    }
    
    // MARK: - Open in Browser Button
    private var openInBrowserButton: some View {
        Button(action: {
            openInSafari()
        }) {
            HStack(spacing: 8) {
                // Use custom globe icon if available, fallback to SF Symbol
                if let globeImage = UIImage(named: "globeIcon") {
                    Image(uiImage: globeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                Text("Open in browser")
                    .font(Design.Font.bold(16))
            }
            .foregroundColor(.white)
            .frame(width: 290, height: 60)
            .background(Design.Color.appGradient)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .background(
            Design.Color.clear
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
        )
    }
    
    // MARK: - Helper Methods
    private func setupWebView() {
        // Normalize URL - add https:// if missing
        let normalizedURLString = normalizeURL(urlString)
        if let url = URL(string: normalizedURLString) {
            currentURL = url
            displayURL = url.host ?? normalizedURLString
            viewModel.currentURL = url
        } else {
            // Set error only if URL is truly invalid
            viewModel.error = NSError(domain: "WebViewError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
    }
    
    private func normalizeURL(_ urlString: String) -> String {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it starts with www., add https://
        if normalized.hasPrefix("www.") {
            normalized = "https://" + normalized
        }
        // If it doesn't have a scheme, add https://
        else if !normalized.contains("://") {
            normalized = "https://" + normalized
        }
        
        return normalized
    }
    
    private func updateDisplayURL(_ url: URL?) {
        if let url = url {
            displayURL = url.host ?? url.absoluteString
            currentURL = url
        }
    }
    
    private func reloadPage() {
        viewModel.error = nil
        if let webView = webViewRef {
            webView.reload()
        } else {
            // If webView not ready, reset URL to trigger reload
            let normalizedURLString = normalizeURL(urlString)
            if let url = currentURL {
                viewModel.currentURL = url
            } else if let url = URL(string: normalizedURLString) {
                currentURL = url
                viewModel.currentURL = url
            }
        }
    }
    
    private func openInSafari() {
        let normalizedURLString = normalizeURL(urlString)
        print("WebViewScreen: Opening in Safari: \(normalizedURLString)")
        if let url = currentURL ?? URL(string: normalizedURLString) {
            UIApplication.shared.open(url)
        } else {
            print("WebViewScreen: Failed to create URL for Safari: \(normalizedURLString)")
        }
    }
    
    private func clearWebData() {
        viewModel.clearWebData(completion: {})
    }
}

// MARK: - In-App WebView Wrapper
struct InAppWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var viewModel: WebViewModel
    @Binding var webViewRef: WKWebView?
    let onURLChange: ((URL?) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKPreferences()
        
        let config = WKWebViewConfiguration()
        config.preferences = prefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()
        
        // Enable JavaScript using the modern API
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable zoom by setting zoom scale limits (zoom is enabled by default, but we can configure it)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        
        // Store webView reference immediately
        DispatchQueue.main.async {
            webViewRef = webView
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update webView reference
        if webViewRef != uiView {
            DispatchQueue.main.async {
                webViewRef = uiView
            }
        }
        
        // Load URL if changed - but only if webView is not currently loading
        if let url = viewModel.currentURL {
            // Only load if URL is different from current AND webView is not loading
            let currentURL = uiView.url
            let isLoading = uiView.isLoading
            
            if currentURL != url && !isLoading {
                uiView.load(URLRequest(url: url))
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel,
            onWebViewCreated: { webView in
                DispatchQueue.main.async {
                    webViewRef = webView
                }
            },
            onURLChange: onURLChange
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: WebViewModel
        let onWebViewCreated: ((WKWebView) -> Void)?
        let onURLChange: ((URL?) -> Void)?
        private var hasNotifiedWebViewCreated = false
        
        init(
            viewModel: WebViewModel,
            onWebViewCreated: ((WKWebView) -> Void)?,
            onURLChange: ((URL?) -> Void)?
        ) {
            self.viewModel = viewModel
            self.onWebViewCreated = onWebViewCreated
            self.onURLChange = onURLChange
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if !hasNotifiedWebViewCreated {
                onWebViewCreated?(webView)
                hasNotifiedWebViewCreated = true
            }
            let urlString = webView.url?.absoluteString ?? "unknown"
            viewModel.isLoading = true
            viewModel.error = nil // Clear any previous errors
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            viewModel.isLoading = false
            viewModel.canGoBack = webView.canGoBack
            viewModel.currentURL = webView.url
            viewModel.error = nil // Clear error on successful load
            onURLChange?(webView.url)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            let nsError = error as NSError
            
            // Only show error for actual failures, not cancellations, redirects, or policy changes
            // Error code -999 is WKErrorFrameLoadInterruptedByPolicyChange (usually a redirect)
            // Error code 102 is WKErrorFrameLoadInterruptedByPolicyChange (Frame load interrupted)
            // Error code -1001 is timeout, -1003 is host not found, -1009 is no internet
            if nsError.code != -999 && nsError.code != 102 {
                print("WebView: Failed to load URL: \(urlString), Error: \(error.localizedDescription), Code: \(nsError.code)")
                viewModel.isLoading = false
                viewModel.error = error
            }
            // Silently ignore -999 and 102 errors (redirects/policy changes) - don't log them
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            let nsError = error as NSError
            
            // Only show error for actual failures, not cancellations or policy changes
            // Error code -999 is WKErrorFrameLoadInterruptedByPolicyChange (cancellation)
            // Error code 102 is WKErrorFrameLoadInterruptedByPolicyChange (Frame load interrupted)
            if nsError.code != -999 && nsError.code != 102 {
                print("WebView: Failed provisional navigation for URL: \(urlString), Error: \(error.localizedDescription), Code: \(nsError.code)")
                viewModel.isLoading = false
                viewModel.error = error
            }
            // Silently ignore -999 and 102 errors (policy changes/interruptions) - don't log them
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation including redirects
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // Enable JavaScript for all pages
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
        }
    }
}
