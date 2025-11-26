//
//  ProfileImageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct ProfileImageView: View {
    var imageUrl: URL?
    var onTap: () -> Void = {}
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Button(action: onTap) {
                if let image = downloadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else {
                    Image("profile-icon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }.onAppear {
                if let httpUrl = imageUrl?.absoluteString {
                    MediaCacheManager.shared.getMedia(
                        url: httpUrl,
                        type: .image,
                        progressHandler: { progress in
                            downloadProgress = progress
                        },
                        completion: { result in
                            switch result {
                            case .success(let fileURL):
                                let fileURL: URL = fileURL.hasPrefix("file://") ? URL(string: fileURL)! : URL(fileURLWithPath: fileURL)
                                
                                // More efficient than loading Data first
                                if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                                    // fallback if the path form fails for some reason
                                    guard let data = try? Data(contentsOf: fileURL) else { return nil }
                                    return UIImage(data: data)
                                }() {
                                    // Optional: pre-decompress for smoother UI on iOS 15+
                                    let finalImage = uiImage.preparingForDisplay() ?? uiImage
                                    DispatchQueue.main.async {
                                        downloadedImage = finalImage
                                    }
                                }
                                
                            case .failure(let error):
                                print("❌ Failed to download media: \(error)")
                            }
                        }
                    )
                }
            }

            StatusIndicator()
        }
    }
}

