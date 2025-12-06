//
//  ProfileImageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct ProfileImageView: View {
    var onTap: () -> Void = {}
    @ObservedObject var profileViewModel: ProfileViewModel
    
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
                downloadProfileImage()
            }

            StatusIndicator()
        }
    }
    
    private func downloadProfileImage() {
        guard let profileMxcUrl = profileViewModel.originalProfile?.profileImageUrl,
              !profileMxcUrl.isEmpty else { return }
        MediaCacheManager.shared.getMedia(
            url: profileMxcUrl,
            type: .image,
            progressHandler: { progress in
                downloadProgress = progress
            },
            completion: { result in
                switch result {
                case .success(let fileURL):
                    let fileURL: URL = fileURL.hasPrefix("file://") ? URL(string: fileURL)! : URL(fileURLWithPath: fileURL)
                    if let uiImage = UIImage(contentsOfFile: fileURL.path) ??
                        (try? Data(contentsOf: fileURL)).flatMap(UIImage.init(data:)) {
                        DispatchQueue.main.async { downloadedImage = uiImage.preparingForDisplay() ?? uiImage }
                    }
                case .failure(let error):
                    print("❌ Failed to download media: \(error)")
                }
            }
        )
    }
}

