//
//  ConversationView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI
import SDWebImageSwiftUI
import UniformTypeIdentifiers

struct ConversationView: View {
    @ObservedObject var roomModel: RoomModel
    var typingIndicator: String
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar and online status
            ZStack(alignment: .bottomTrailing) {
                // Use SDWebImage for async image loading
                if let image = downloadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else {
                    Text(getInitials(from: roomModel.name))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Color.primaryText.opacity(0.7))
                        .frame(width: 48, height: 48)  // Set the circle size
                        .background(roomModel.randomeProfileColor.opacity(0.3))
                        .clipShape(Circle())
                }
                
                // Show online status indicator
                if !roomModel.isGroup, let isOpponentOnline = roomModel.opponent?.isOnline, isOpponentOnline {
                    StatusIndicator()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                // Room name and time
                HStack {
                    Text(roomModel.name)
                        .font(roomModel.unreadCount > 0 ? Design.Font.bold(14) : Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText)
                    
                    Spacer()
                    
                    Text(lastActiveString(from: roomModel.opponent?.lastSeen))
                        .font(Design.Font.regular(12))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                }
                
                if !typingIndicator.isEmpty {
                    Text(typingIndicator)
                        .font(Design.Font.regular(12))
                        .foregroundColor(Design.Color.primaryText.opacity(0.4))
                        .lineLimit(1)
                } else {
                    HStack {
                        // Last sender (only for group)
                        if roomModel.isGroup {
                            Text(!(roomModel.lastSenderName?.isEmpty ?? true) ? "\(roomModel.lastSenderName ?? "") :" : "")
                                .font(Design.Font.regular(12))
                                .foregroundColor(Design.Color.primaryText.opacity(0.4))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                        // Last message text
                        lastMessagePreview
                            .font(roomModel.unreadCount > 0 ? Design.Font.semiBold(12) : Design.Font.regular(12))
                            .foregroundColor(roomModel.unreadCount > 0 ? Design.Color.primaryText : Design.Color.primaryText.opacity(0.4))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer().frame(width: 12)
                        
                        if roomModel.isMuted {
                            Image("notification-bing")
                                .frame(width: 10, height: 10)
                        }
                        
                        // Unread message count indicator
                        if roomModel.unreadCount > 0 {
                            Text(roomModel.unreadCount > 99 ? "99+" : "\(roomModel.unreadCount)")
                                .font(Design.Font.semiBold(10))
                                .foregroundColor(Design.Color.white)
                                .frame(minWidth: 24, minHeight: 16)
                                .padding(.horizontal, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Design.Color.appGradient)
                                )
                        } else {
                            if !roomModel.isRead {
                                Circle()
                                    .fill(Design.Color.appGradient)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if let httpUrl = roomModel.avatarUrl, !httpUrl.isEmpty  {
                MediaCacheManager.shared.getMedia(
                    url: httpUrl,
                    type: .image,
                    progressHandler: { progress in
                        downloadProgress = progress
                    },
                    completion: { result in
                        switch result {
                        case .success(let pathString):
                            let fileURL: URL = pathString.hasPrefix("file://")
                                ? (URL(string: pathString) ?? URL(fileURLWithPath: pathString))
                                : URL(fileURLWithPath: pathString)

                            DispatchQueue.global(qos: .userInitiated).async {
                                autoreleasepool {
                                    do {
                                        // 1) Exists & not a directory
                                        var isDir: ObjCBool = false
                                        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                              !isDir.boolValue else {
                                            throw NSError(domain: "Avatar", code: 4001,
                                                          userInfo: [NSLocalizedDescriptionKey: "Missing avatar file"])
                                        }

                                        // 2) Type-gate: only decode images
                                        if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                           !ut.conforms(to: .image) {
                                            throw NSError(domain: "Avatar", code: 4002,
                                                          userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                        }

                                        // 3) Downsample via ImageIO (low memory)
                                        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                        var ui: UIImage? = nil
                                        if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                            let opts: [CFString: Any] = [
                                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                kCGImageSourceShouldCacheImmediately: true,
                                                kCGImageSourceCreateThumbnailWithTransform: true,
                                                kCGImageSourceThumbnailMaxPixelSize: 512
                                            ]
                                            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                                ui = UIImage(cgImage: cg)
                                            }
                                        }

                                        // 4) Fallbacks
                                        if ui == nil { ui = UIImage(contentsOfFile: fileURL.path) }
                                        if ui == nil {
                                            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                            ui = UIImage(data: data)
                                        }
                                        guard var img = ui else {
                                            throw NSError(domain: "Avatar", code: 4003,
                                                          userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                        }

                                        if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() {
                                            img = prepped
                                        }

                                        DispatchQueue.main.async { downloadedImage = img }

                                    } catch {
                                        print("❌ Avatar decode error:", error)
                                    }
                                }
                            }

                        case .failure(let error):
                            print("❌ Failed to download media:", error)
                        }
                    }
                )
            }
        }
    }
    
    private var lastMessagePreview: some View {
        switch MessageType(from: roomModel.lastMessageType) {
        case .text:
            return AnyView(Text(roomModel.lastMessage ?? "No messages"))
        case .image:
            return AnyView(Label("Photo", systemImage: "photo.fill"))
        case .video:
            return AnyView(Label("Video", systemImage: "video.fill"))
        case .audio:
            return AnyView(Label("Audio", systemImage: "waveform"))
        case .file:
            return AnyView(Label("File", systemImage: "doc.fill"))
        case .gif:
            return AnyView(Label("GIF", systemImage: "sparkles"))
        }
    }

}
