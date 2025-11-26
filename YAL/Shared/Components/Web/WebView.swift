//
//  WebView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    let onStart: (() -> Void)?
    let onFinish: (() -> Void)?
    let onError: ((Error) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStart: onStart, onFinish: onFinish, onError: onError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onStart: (() -> Void)?
        let onFinish: (() -> Void)?
        let onError: ((Error) -> Void)?

        init(onStart: (() -> Void)?, onFinish: (() -> Void)?, onError: ((Error) -> Void)?) {
            self.onStart = onStart
            self.onFinish = onFinish
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onStart?()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinish?()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError?(error)
        }
    }
}
