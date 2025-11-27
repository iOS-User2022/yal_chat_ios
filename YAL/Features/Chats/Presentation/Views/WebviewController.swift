//
//  WebviewController.swift
//  YAL
//
//  Created by Amutha on 27/11/25.
//

import SwiftUI

import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var model: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKPreferences()
//        prefs.javaScriptEnabled = true

        let config = WKWebViewConfiguration()
        config.preferences = prefs
        config.allowsInlineMediaPlayback = true
        config.websiteDataStore = .default()

        let webview = WKWebView(frame: .zero, configuration: config)
        webview.navigationDelegate = context.coordinator
        webview.allowsBackForwardNavigationGestures = true
//        webview.scrollView.isZooming = true

        return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = model.currentURL, uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var model: WebViewModel
        init(model: WebViewModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.isLoading = true
            model.error = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false
            model.canGoBack = webView.canGoBack
            model.currentURL = webView.url
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            model.error = error
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            model.error = error
        }
    }
}
import Foundation
import Combine
import WebKit

final class WebViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var error: Error?

    func clearWebData(completion: @escaping () -> Void = {}) {
        // Clear cookies & caches
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                URLCache.shared.removeAllCachedResponses()
                HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
                completion()
            }
        }
    }
}
