//
//  ChatHeaderView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatHeaderView: View {
    let title: String
    let subtitle: String
    let image: String?
    let color: Color?
    var backAction: (() -> Void)?
    @State private var downloadedImage: UIImage?
    private let processQ = DispatchQueue(label: "chat.vm.process", qos: .userInitiated)

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {
                backAction?()
            }) {
                Image("back-long")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            
            Spacer().frame(width: 12)
            
            ZStack {
                if let uiImage = downloadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: title))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Color.primaryText.opacity(0.7))
                        .frame(width: 48, height: 48)  // Set the circle size
                        .background(color.opacity(0.3))
                        .clipShape(Circle())
                }
            }.onAppear {
                if let avatarUrl = image {
                    MediaCacheManager.shared.getMedia(
                        url: avatarUrl,
                        type: .image,
                        progressHandler: { _ in}
                    ) { result in
                        switch result {
                        case .success(let imagePath):
                            processQ.async {
                                autoreleasepool {
                                    do {                                        
                                        // Build a file URL safely
                                        let fileURL: URL
                                        if let u = URL(string: imagePath), u.scheme == "file" {
                                            fileURL = u
                                        } else {
                                            fileURL = URL(fileURLWithPath: imagePath)
                                        }
                                        
                                        // Make sure the file exists and isn't a directory
                                        var isDir: ObjCBool = false
                                        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                                            throw NSError(domain: "Media", code: 1001, userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                        }
                                        
                                        // Optional: quick type gate (prevents PDF/MP4/MP3 from hitting ImageIO)
                                        if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                           !ut.conforms(to: .image) {
                                            throw NSError(domain: "Media", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Not an image type: \(ut.identifier)"])
                                        }
                                        
                                        // Fast path: decode from file (doesn't allocate entire file in RAM)
                                        if let img = UIImage(contentsOfFile: fileURL.path)?.preparingForDisplay() {
                                            DispatchQueue.main.async { self.downloadedImage = img }
                                            return
                                        }
                                        
                                        // Fallback: load data (use mappedIfSafe to avoid large copies)
                                        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                        guard let img = UIImage(data: data)?.preparingForDisplay() else {
                                            throw NSError(domain: "Media", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image bytes"])
                                        }
                                        
                                        DispatchQueue.main.async { self.downloadedImage = img }
                                        
                                    } catch {
                                        print("❌ Image load error: \(error.localizedDescription) — path=\(imagePath)")
                                        DispatchQueue.main.async {
                                            self.downloadedImage = nil   // or set a placeholder
                                        }
                                    }
                                }
                            }
                        case .failure(let e):
                            print("image load failed:", e)
                        }
                    }
                }
            }
            
            Spacer().frame(width: 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Design.Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top,0)
                Text(subtitle)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top,-8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer().frame(width: 12)

        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color.white)
    }
}
