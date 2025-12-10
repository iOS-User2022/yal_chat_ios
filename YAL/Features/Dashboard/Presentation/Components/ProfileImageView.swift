//
//  ProfileImageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI
import SDWebImageSwiftUI
import UniformTypeIdentifiers

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
                case .success(let pathString):
                    // Build a safe file URL from either "file://…" or raw path
                    let localURL: URL = {
                        if let u = URL(string: pathString), u.scheme == "file" { return u }
                        return URL(fileURLWithPath: pathString)
                    }()

                    DispatchQueue.global(qos: .userInitiated).async {
                        autoreleasepool {
                            do {
                                // 1) Exists & not a directory
                                var isDir: ObjCBool = false
                                guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDir),
                                      !isDir.boolValue else {
                                    throw NSError(domain: "Media", code: 8101,
                                                  userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                }

                                // 2) Type-gate: only decode images
                                if let ut = UTType(filenameExtension: localURL.pathExtension),
                                   !ut.conforms(to: .image) {
                                    throw NSError(domain: "Media", code: 8102,
                                                  userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                }

                                // 3) Downsample with ImageIO (low memory)
                                let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                var img: UIImage? = nil
                                if let src = CGImageSourceCreateWithURL(localURL as CFURL, srcOpts as CFDictionary) {
                                    let opts: [CFString: Any] = [
                                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceShouldCacheImmediately: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 1536
                                    ]
                                    if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                        img = UIImage(cgImage: cg)
                                    }
                                }

                                // 4) Fallbacks
                                if img == nil { img = UIImage(contentsOfFile: localURL.path) }
                                if img == nil {
                                    let data = try Data(contentsOf: localURL, options: [.mappedIfSafe])
                                    img = UIImage(data: data)
                                }
                                guard var ui = img else {
                                    throw NSError(domain: "Media", code: 8103,
                                                  userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                }

                                if #available(iOS 15.0, *), let prepped = ui.preparingForDisplay() { ui = prepped }

                                DispatchQueue.main.async { downloadedImage = ui }

                            } catch {
                                print("❌ Media decode error — \(error.localizedDescription) | \(localURL.path)")
                            }
                        }
                    }

                case .failure(let error):
                    print("❌ Failed to download media: \(error)")
                }
            }
        )
    }
}

