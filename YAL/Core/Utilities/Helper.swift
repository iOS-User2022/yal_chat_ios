//
//  Helper.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/05/25.
//

import Foundation
import UIKit
import AVFoundation
import SwiftUI
import PDFKit
import Combine
import UniformTypeIdentifiers
import QuickLookThumbnailing
import ImageIO

func mimeTypeForFileExtension(_ ext: String) -> String {
    switch ext.lowercased() {
    case "gif": return "image/gif"
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    case "mp4": return "video/mp4"
    case "mov": return "video/quicktime"
    case "m4a": return "audio/m4a"
    case "mp3": return "audio/mpeg"
    case "pdf": return "application/pdf"
    case "vcf": return "text/vcard"
    case "json": return "application/json"
    case "txt": return "text/plain"
    case "doc": return "application/msword"
    case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "m4v": return "video/x-m4v"
    default: return "application/octet-stream"
    }
}

func fileExtensionForMimeType(mimeType: String) -> String {
    switch mimeType.lowercased() {
    case "image/gif": return "gif"
    case "image/jpeg": return "jpg"
    case "image/png": return "png"
    case "video/mp4": return "mp4"
    case "video/quicktime": return "mov"
    case "audio/m4a": return "m4a"
    case "audio/mpeg": return "mp3"
    case "application/pdf": return "pdf"
    case "text/vcard": return "vcf"
    case "application/json": return "json"
    case "text/plain": return "txt"
    case "application/msword": return "doc"
    case "video/x-m4v": return "m4v"
    case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": return "docx"
    default: return "dat" // generic binary
    }
}

func messageType(for mimeType: String) -> MessageType {
    if mimeType == "image/gif" { return .gif }
    if mimeType.hasPrefix("image/") { return .image }
    if mimeType.hasPrefix("video/") { return .video }
    if mimeType.hasPrefix("audio/") { return .audio }
    if mimeType == "text/plain" { return .text }
    return .file
}

func mxcToHttp(_ mxc: String) -> String {
    let base = "https://"
    return mxc.replacingOccurrences(of: "mxc://", with: base)
}

func mxcDownloadURL(_ mxc: String, homeserverBase: URL) -> URL? {
    guard let (server, mediaId) = parseMXC(mxc: mxc) else { return nil }
    var u = homeserverBase
    u.appendPathComponent("_matrix")
    u.appendPathComponent("media")
    u.appendPathComponent("v3")
    u.appendPathComponent("download")
    u.appendPathComponent(server)
    u.appendPathComponent(mediaId)
    return u
}

func mxcThumbnailURL(_ mxc: String,
                     homeserverBase: URL,
                     width: Int,
                     height: Int,
                     method: String = "scale") -> URL? {
    guard let (server, mediaId) = parseMXC(mxc: mxc) else { return nil }
    var u = homeserverBase
    u.appendPathComponent("_matrix")
    u.appendPathComponent("media")
    u.appendPathComponent("v3")
    u.appendPathComponent("thumbnail")
    u.appendPathComponent(server)
    u.appendPathComponent(mediaId)

    var comps = URLComponents(url: u, resolvingAgainstBaseURL: false)
    comps?.queryItems = [
        .init(name: "width", value: "\(width)"),
        .init(name: "height", value: "\(height)"),
        .init(name: "method", value: method)
    ]
    return comps?.url
}

func writeDataToTempFile(data: Data, fileExtension: String) -> URL? {
    let fileName = UUID().uuidString + "." + fileExtension
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    do {
        try data.write(to: tempURL)
        return tempURL
    } catch {
        print("❌ Failed to write data to temp file:", error)
        return nil
    }
}

func buildMatrixMediaInfo(
    fileURL: URL,
    msgType: MessageType,
    completion: @escaping (MediaInfo?) -> Void
) {
    let ext = fileURL.pathExtension
    let mimeType = mimeTypeForFileExtension(ext)
    
    guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int else {
        completion(nil)
        return
    }
    
    var width: Int? = nil
    var height: Int? = nil
    var duration: Int? = nil
    
    switch msgType {
    case .image:
        if let image = UIImage(contentsOfFile: fileURL.path) {
            width = Int(image.size.width)
            height = Int(image.size.height)
        }
        completion(
            MediaInfo(
                thumbnailUrl: nil,
                thumbnailInfo: nil,
                w: width,
                h: height,
                duration: duration,
                size: fileSize,
                mimetype: mimeType
            )
        )
        
    case .video, .audio:
        let asset = AVURLAsset(url: fileURL)
        
        Task {
            do {
                let durationSeconds = try await asset.load(.duration).seconds
                duration = Int(durationSeconds * 1000)
                
                if msgType == .video {
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    if let videoTrack = tracks.first {
                        let size = try await videoTrack.load(.naturalSize)
                        let transform = try await videoTrack.load(.preferredTransform)
                        let transformedSize = size.applying(transform)
                        width = Int(abs(transformedSize.width))
                        height = Int(abs(transformedSize.height))
                    }
                }
                
                completion(
                    MediaInfo(
                        thumbnailUrl: nil,
                        thumbnailInfo: nil,
                        w: width,
                        h: height,
                        duration: duration,
                        size: fileSize,
                        mimetype: mimeType
                    )
                )
            } catch {
                print("⚠️ Error reading AVAsset metadata: \(error)")
                completion(nil)
            }
        }
        
    case .file:
        
        completion(
            MediaInfo(
                thumbnailUrl: nil,
                thumbnailInfo: nil,
                w: width,
                h: height,
                duration: duration,
                size: fileSize,
                mimetype: mimeType
            )
        )
    case .text:
        break
    case .gif:
        if let image = UIImage(contentsOfFile: fileURL.path) {
            width = Int(image.size.width)
            height = Int(image.size.height)
        }
        completion(
            MediaInfo(
                thumbnailUrl: nil,
                thumbnailInfo: nil,
                w: width,
                h: height,
                duration: duration,
                size: fileSize,
                mimetype: mimeType
            )
        )
    }
}

func parseMXC(mxc: String) -> (String, String)? {
    guard mxc.starts(with: "mxc://") else { return nil }
    let parts = mxc.dropFirst("mxc://".count).split(separator: "/")
    guard parts.count == 2 else { return nil }
    return (String(parts[0]), String(parts[1]))
}

// Function to get the initials from the full name

func getInitials(from name: String) -> String {
    let components = name.split(separator: " ")
    let initials = components.prefix(2).compactMap { $0.first }
    return initials.map { String($0) }.joined()
}

// Function to generate a random background color for the circle
func randomBackgroundColor() -> Color {
    // Generate a random RGB value for the color
    let red = Double.random(in: 0.2...1.0)
    let green = Double.random(in: 0.2...1.0)
    let blue = Double.random(in: 0.2...1.0)
    return Color(red: red, green: green, blue: blue)
}

func lastActiveString(from millis: Int?) -> String {
    guard let millis = millis else { return "" }
    let nowMillis = Int(Date().timeIntervalSince1970 * 1000)
    let deltaSeconds = max((nowMillis - millis) / 1000, 0) // Ensure non-negative
    
    if deltaSeconds < 30 {
        return "just now"
    } else if deltaSeconds < 60 {
        return "a moment ago"
    } else if deltaSeconds < 3600 {
        let mins = deltaSeconds / 60
        return "\(mins) min\(mins == 1 ? "" : "s") ago"
    } else if deltaSeconds < 86400 {
        let hours = deltaSeconds / 3600
        return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    } else if deltaSeconds < 604800 {
        let days = deltaSeconds / 86400
        return "\(days) day\(days == 1 ? "" : "s") ago"
    } else if deltaSeconds < 2592000 {
        let weeks = deltaSeconds / 604800
        return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
    } else if deltaSeconds < 31536000 {
        let months = deltaSeconds / 2592000
        return "\(months) month\(months == 1 ? "" : "s") ago"
    } else {
        let years = deltaSeconds / 31536000
        return "\(years) year\(years == 1 ? "" : "s") ago"
    }
}


func getMediaDimensions(mediaType: String, localURL: String?) -> (Int, Int) {
    guard let localURL, let url = makeURL(from: localURL) else { return (0, 0) }

    switch mediaType {
    case MessageType.image.rawValue, MessageType.gif.rawValue:
        return imagePixelSize(for: url)

    case MessageType.video.rawValue:
        return videoPixelSize(for: url)

    case MessageType.audio.rawValue:
        // No meaningful pixel dimension for audio; let the UI choose.
        return (0, 0)

    case MessageType.file.rawValue:
        return documentPixelSize(for: url)

    default:
        return (0, 0)
    }
}

// MARK: - Images (incl. GIF first frame, HEIC, etc.) — metadata fast-path, decode fallback
private func imagePixelSize(for url: URL) -> (Int, Int) {
    if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
       let w = (props[kCGImagePropertyPixelWidth]  as? NSNumber)?.doubleValue,
       let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue {
        return (Int(w.rounded()), Int(h.rounded()))
    }

    // Fallback (points → pixels using image.scale)
    if let img = UIImage(contentsOfFile: url.path) {
        let pxW = img.size.width  * img.scale
        let pxH = img.size.height * img.scale
        return (Int(pxW.rounded()), Int(pxH.rounded()))
    }

    return (0, 0)
}

// MARK: - Video — use track naturalSize with preferredTransform (fast), frame-grab as fallback
private func videoPixelSize(for url: URL) -> (Int, Int) {
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero
    gen.requestedTimeToleranceAfter  = .zero
    if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
        return (cg.width, cg.height)
    }
    return (0, 0)
}

// MARK: - Documents — PDF via PDFKit; otherwise try image metadata; else (0,0)
private func documentPixelSize(for url: URL) -> (Int, Int) {
    let ext = url.pathExtension.lowercased()

    // Prefer UTType if available
    if let ut = UTType(filenameExtension: ext) {
        #if canImport(PDFKit)
        if ut.conforms(to: .pdf),
           let pdf = PDFDocument(url: url),
           let page = pdf.page(at: 0) {
            // PDF page bounds are in points @72dpi; map to pixels with screen scale (keeps aspect ratio)
            let rect  = page.bounds(for: .mediaBox)
            let scale = UIScreen.main.scale
            let w = max(Int((rect.width  * scale).rounded()),  1)
            let h = max(Int((rect.height * scale).rounded()), 1)
            return (w, h)
        }
        #endif

        // Some “documents” are actually images (e.g., .webp on iOS17+ if supported)
        if ut.conforms(to: .image) {
            return imagePixelSize(for: url)
        }
    } else {
        // Heuristic: treat common PDFs explicitly when UTType couldn’t be constructed
        #if canImport(PDFKit)
        if ext == "pdf",
           let pdf = PDFDocument(url: url),
           let page = pdf.page(at: 0) {
            let rect  = page.bounds(for: .mediaBox)
            let scale = UIScreen.main.scale
            return (Int((rect.width * scale).rounded()),
                    Int((rect.height * scale).rounded()))
        }
        #endif
    }

    // Last-chance metadata probe (covers image-like docs renamed oddly)
    if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
       let w = (props[kCGImagePropertyPixelWidth]  as? NSNumber)?.intValue,
       let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue {
        return (w, h)
    }

    return (0, 0)
}

private func makeURL(from string: String) -> URL? {
    if string.hasPrefix("file://") || string.hasPrefix("http://") || string.hasPrefix("https://") {
        return URL(string: string)
    } else {
        return URL(fileURLWithPath: string) // raw local path
    }
}

func videoThumbnail(url: URL, at seconds: Double = 0.1) -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    do {
        let cg = try generator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cg)
    } catch {
        return nil
    }
}

func fileSizeBytes(at url: URL) -> Int64 {
    (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ??
    (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
}

func durationPublisher(for url: URL) -> AnyPublisher<Double, Never> {
    Future { promise in
        loadDurationSeconds(at: url) { secs in
            promise(.success(secs))
        }
    }
    .eraseToAnyPublisher()
}

func loadDurationSeconds(at url: URL, completion: @escaping (Double) -> Void) {
    let asset = AVURLAsset(url: url)

    if #available(iOS 16.0, *) {
        Task.detached {
            do {
                let time = try await asset.load(.duration)
                let secs = CMTimeGetSeconds(time)
                await MainActor.run { completion(secs.isFinite ? secs : 0) }
            } catch {
                await MainActor.run { completion(0) }
            }
        }
    } else {
        // Older API (non-deprecated) path
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            let secs: Double
            if status == .loaded {
                secs = CMTimeGetSeconds(asset.duration)
            } else {
                secs = 0
            }
            DispatchQueue.main.async { completion(secs.isFinite ? secs : 0) }
        }
    }
}

func makeVideoThumbnail(url: URL) -> UIImage? {
    let asset = AVURLAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
    if let cg = try? gen.copyCGImage(at: time, actualTime: nil) {
        return UIImage(cgImage: cg)
    }
    return nil
}

func loadImagePreview(from url: URL, maxPixelSize: CGFloat = 2048) -> UIImage? {
    do {
        // 1) Basic sanity
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            throw NSError(domain: "Media", code: 3001,
                          userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory (\(url.path))"])
        }

        // 2) Gate by type so PDFs/MP4/MP3 never hit ImageIO as images
        if let ut = UTType(filenameExtension: url.pathExtension), !ut.conforms(to: .image) {
            throw NSError(domain: "Media", code: 3002,
                          userInfo: [NSLocalizedDescriptionKey: "Not an image type: \(ut.identifier)"])
        }

        // 3) Streamed, downsampled decode (fast + low memory)
        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        if let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts as CFDictionary) {
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(max(1, maxPixelSize))
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) {
                let ui = UIImage(cgImage: cg)
                if #available(iOS 15.0, *) { return ui.preparingForDisplay() ?? ui }
                return ui
            }
        }

        // 4) Fallbacks
        if let img = UIImage(contentsOfFile: url.path) {
            if #available(iOS 15.0, *) { return img.preparingForDisplay() ?? img }
            return img
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let img2 = UIImage(data: data) else {
            throw NSError(domain: "Media", code: 3003,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to decode image bytes"])
        }
        if #available(iOS 15.0, *) { return img2.preparingForDisplay() ?? img2 }
        return img2

    } catch {
        print("❌ loadImagePreview error: \(error.localizedDescription) — \(url.path)")
        return nil
    }
}

// MARK: - Cross-module preview helpers (Images, Video, Documents)

/// Unified preview entry-point: returns a UIImage for the given media type & URL.
func previewImage(
    for type: MediaType,
    url: URL,
    completion: @escaping (Result<UIImage, Error>) -> Void
) {
    switch type {
    case .image, .gif:
        decodeImageAsync(from: url, completion: completion)

    case .video:
        generateVideoThumbnailAsync(from: url, completion: completion)

    case .document:
        generateDocumentThumbnailAsync(from: url, completion: completion)

    case .audio:
        // No raster preview for audio.
        completion(.failure(NSError(domain: "Preview", code: 1, userInfo: [NSLocalizedDescriptionKey: "No preview for audio."])))
    }
}

// MARK: Images (incl. GIF first frame)
func decodeImageAsync(
    from url: URL,
    maxPixelSize: CGFloat = 2048,
    completion: @escaping (Result<UIImage, Error>) -> Void
) {
    DispatchQueue.global(qos: .userInitiated).async {
        autoreleasepool {
            do {
                // 1) Exists & not a directory
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      !isDir.boolValue else {
                    throw NSError(domain: "Preview", code: 2101,
                                  userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory (\(url.path))"])
                }

                // 2) Type gate to avoid decoding PDFs/MP4/MP3 as images
                if let ut = UTType(filenameExtension: url.pathExtension),
                   !ut.conforms(to: .image) {
                    throw NSError(domain: "Preview", code: 2102,
                                  userInfo: [NSLocalizedDescriptionKey: "Not an image type: \(ut.identifier)"])
                }

                // 3) Downsample via ImageIO (fast + low memory)
                let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                if let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts as CFDictionary) {
                    let thumbOpts: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: Int(max(1, maxPixelSize))
                    ]
                    if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) {
                        var ui = UIImage(cgImage: cg)
                        if #available(iOS 15.0, *), let prepped = ui.preparingForDisplay() { ui = prepped }
                        DispatchQueue.main.async { completion(.success(ui)) }
                        return
                    }
                }

                // 4) Fallbacks
                if var ui = UIImage(contentsOfFile: url.path) {
                    if #available(iOS 15.0, *), let prepped = ui.preparingForDisplay() { ui = prepped }
                    DispatchQueue.main.async { completion(.success(ui)) }
                    return
                }

                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                guard var ui2 = UIImage(data: data) else {
                    throw NSError(domain: "Preview", code: 2103,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to decode image bytes"])
                }
                if #available(iOS 15.0, *), let prepped = ui2.preparingForDisplay() { ui2 = prepped }
                DispatchQueue.main.async { completion(.success(ui2)) }

            } catch {
                print("❌ decodeImageAsync error: \(error.localizedDescription) — \(url.path)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

// MARK: Video thumbnail via AVAssetImageGenerator (non-deprecated)
func generateVideoThumbnailAsync(
    from url: URL,
    at seconds: Double = 0.5,
    completion: @escaping (Result<UIImage, Error>) -> Void
) {
    DispatchQueue.global(qos: .userInitiated).async {
        autoreleasepool {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter  = .zero

            let times: [CMTime] = [CMTime(seconds: seconds, preferredTimescale: 600), .zero]
            for t in times {
                if let cg = try? gen.copyCGImage(at: t, actualTime: nil) {
                    let ui = UIImage(cgImage: cg)
                    DispatchQueue.main.async { completion(.success(ui)) }
                    return
                }
            }

            let err = NSError(domain: "Preview", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate video thumbnail"])
            DispatchQueue.main.async { completion(.failure(err)) }
        }
    }
}

// MARK: Documents — QuickLook thumbnails (PDF, Office, etc.) with graceful fallback
func generateDocumentThumbnailAsync(
    from url: URL,
    maxPixelSize: CGFloat = 600,
    completion: @escaping (Result<UIImage, Error>) -> Void
) {
    #if canImport(QuickLookThumbnailing)
    let req = QLThumbnailGenerator.Request(
        fileAt: url,
        size: CGSize(width: maxPixelSize, height: maxPixelSize),
        scale: UIScreen.main.scale,
        representationTypes: .thumbnail
    )
    QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { thumb, err in
        if let img = thumb?.uiImage {
            DispatchQueue.main.async { completion(.success(img)) }
        } else if let err {
            // Fallback to "try decode like an image"
            decodeImageAsync(from: url, completion: completion)
            // If you'd rather surface the error, use:
            // DispatchQueue.main.async { completion(.failure(err)) }
        } else {
            // Unknown failure: fallback to image decode
            decodeImageAsync(from: url, completion: completion)
        }
    }
    #else
    // Fallback: try to decode as an image-like file if QuickLook isn’t available
    decodeImageAsync(from: url, completion: completion)
    #endif
}
