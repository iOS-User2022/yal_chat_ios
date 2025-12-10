//
//  MediaDecodeHelper.swift
//  YAL
//
//  Created by Vishal Bhadade on 09/12/25.
//


import UIKit
import ImageIO
import UniformTypeIdentifiers
import SwiftUI
import AVFoundation

enum MediaDecodeHelper {
    // Small in-memory cache for already downsampled thumbnails
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 0                    // use cost not count
        c.totalCostLimit = 64 * 1024 * 1024 // ~64 MB
        return c
    }()

    private static func setCache(_ image: UIImage, forKey key: NSString) {
        // rough bytes = w * h * 4 * scale^2
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
    }
    
    // MARK: - Public API

    /// Downsample + cache a bitmap for list cells (fast, tiny, stutter-free)
    static func downsampleCached(url: URL, maxPixel: CGFloat) -> UIImage? {
        let key = cacheKey(url: url, pixel: maxPixel) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard isImage(url) else { return nil }

        guard let img = downsample(url: url, maxPixel: maxPixel) else { return nil }
        setCache(img, forKey: key)
        return img
    }
    
    static func downsampleAsync(url: URL, maxPixel: CGFloat) async -> UIImage? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: downsampleCached(url: url, maxPixel: maxPixel))
            }
        }
    }
    
    static func videoPoster(url: URL, maxPixel: CGFloat) -> UIImage? {
        let key = "vid-\(url.path)@\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let asset = AVAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let px = maxPixel * UIScreen.main.scale
        gen.maximumSize = CGSize(width: px, height: px)

        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil)
        else { return nil }

        let img = UIImage(cgImage: cg)
        setCache(img, forKey: key)
        return img
    }

    /// Assign on main without implicit animations (keeps UI thread cool)
    static func setWithoutAnimation<T>(_ apply: @escaping () -> T) {
        if Thread.isMainThread {
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) { _ = apply() }
        } else {
            DispatchQueue.main.async {
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { _ = apply() }
            }
        }
    }

    /// Coarse progress to reduce view invalidations (5% steps by default)
    static func quantizeProgress(_ v: Double, steps: Int = 20) -> Double {
        let clamped = max(0, min(1, v))
        return Double(Int(clamped * Double(steps))) / Double(steps)
    }

    // MARK: - Internals

    private static func isImage(_ url: URL) -> Bool {
        guard let ut = UTType(filenameExtension: url.pathExtension) else { return false }
        return ut.conforms(to: .image)
    }

    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Avoid decoding full-size into cache:
            kCGImageSourceShouldCache: false
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func cacheKey(url: URL, pixel: CGFloat) -> String {
        url.path + "@\(Int(pixel))"
    }
}

// Downsampled local image view (async + no implicit animations)
struct DownsampledLocalImage: View {
    let url: URL
    let maxPixel: CGFloat
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Color(.systemGray6)
            }
        }
        .task(id: url) {
            let img = await MediaDecodeHelper.downsampleAsync(url: url, maxPixel: maxPixel)
            MediaDecodeHelper.setWithoutAnimation { self.uiImage = img }
        }
    }
}

// Downsampled local video poster
struct DownsampledVideoPoster: View {
    let url: URL
    let maxPixel: CGFloat
    @State private var uiImage: UIImage?

    var body: some View {
        ZStack {
            Group {
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                } else {
                    Color(.black).opacity(0.1)
                }
            }
            Image(systemName: "play.circle.fill")
                .resizable().frame(width: 40, height: 40)
                .foregroundColor(.white).shadow(radius: 5)
        }
        .task(id: url) {
            let img: UIImage? = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let poster = MediaDecodeHelper.videoPoster(url: url, maxPixel: maxPixel)
                    cont.resume(returning: poster)
                }
            }
            MediaDecodeHelper.setWithoutAnimation {
                self.uiImage = img
            }
        }
    }
}
