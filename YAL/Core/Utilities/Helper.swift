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
    case "doc", "docx": return "application/msword"
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

func getMediaDimensions(
    mediaType: String,
    localURL: String?,
    completion: @escaping (Int, Int) -> Void
) {
    guard let urlString = localURL, let url = URL(string: urlString) else {
        completion(0, 0)
        return
    }
    if mediaType == MessageType.image.rawValue || mediaType == MessageType.gif.rawValue {
        if let image = UIImage(contentsOfFile: url.path) {
            completion(Int(image.size.width.rounded()), Int(image.size.height.rounded()))
        } else {
            completion(0, 0)
        }
    } else if mediaType == MessageType.video.rawValue {
        let asset = AVAsset(url: url)
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    if let track = tracks.first {
                        let size = try await track.load(.naturalSize)
                        let transform = try await track.load(.preferredTransform)
                        let transformedSize = size.applying(transform)
                        completion(Int(abs(transformedSize.width)), Int(abs(transformedSize.height)))
                    } else {
                        completion(0, 0)
                    }
                } catch {
                    completion(0, 0)
                }
            }
        } else {
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                completion(Int(abs(size.width)), Int(abs(size.height)))
            } else {
                completion(0, 0)
            }
        }
    } else {
        completion(0, 0)
    }
}
