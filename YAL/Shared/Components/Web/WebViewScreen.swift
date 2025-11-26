//
//  WebViewScreen.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct WebViewScreen: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") {
                    dismiss()
                }
                .padding()

                Spacer()
            }

            if let url = URL(string: urlString) {
                WebView(
                    url: url,
                    onStart: { isLoading = true },
                    onFinish: { isLoading = false },
                    onError: { error in print("Error loading page:", error.localizedDescription) }
                )
            } else {
                Text("Invalid URL")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .overlay(
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(.circular)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            },
            alignment: .center
        )
    }
}
