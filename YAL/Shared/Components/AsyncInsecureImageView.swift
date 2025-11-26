//
//  AsyncInsecureImageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct AsyncInsecureImageView: View {
    let urlString: String
    var placeholder: Image = Image(systemName: "photo")

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = URL(string: urlString) else { return }

        let session = URLSession(
            configuration: .default,
            delegate: InsecureSessionDelegate(),
            delegateQueue: nil
        )

        session.dataTask(with: url) { data, _, error in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.uiImage = img
                }
            } else if let error = error {
                print("⚠️ Insecure image load failed:", error.localizedDescription)
            }
        }.resume()
    }

    private class InsecureSessionDelegate: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession,
                        didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}
