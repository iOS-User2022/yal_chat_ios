//
//  HttpClient.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation
import Combine
import UniformTypeIdentifiers
import UIKit

final class HttpClient: NSObject, HttpClientProtocol {
    private let session: URLSession
    private let tokenProvider: TokenProvider
    var isMatrixClient: Bool = false

    // Handlers by task ID
    @nonobjc private var downloadProgressHandlers: [Int: (Double) -> Void] = [:]
    @nonobjc private var downloadCompletionHandlers: [Int: (Result<URL, Error>) -> Void] = [:]
    @nonobjc private var uploadProgressHandlers: [Int: (Double) -> Void] = [:]
    @nonobjc private var uploadCompletionHandlers: [Int: (Result<URL, Error>) -> Void] = [:]
    @nonobjc private var uploadResponseData: [Int: Data] = [:]
    
    private let handlersQ = DispatchQueue(label: "yal.http.handlers", attributes: .concurrent)
    private let sessionDelegate = HttpClientSessionDelegate()
    
    init(tokenProvider: TokenProvider, timeout: TimeInterval = 10.0, enableSSLPinning: Bool = false) {
        self.tokenProvider = tokenProvider
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
        super.init()
        sessionDelegate.owner = self
    }

    // Download handlers
    func setDownloadProgressHandler(_ handler: ((Double) -> Void)?, for id: Int) {
        handlersQ.async(flags: .barrier) { self.downloadProgressHandlers[id] = handler }
    }
    
    func setDownloadCompletionHandler(_ handler: ((Result<URL, Error>) -> Void)?, for id: Int) {
        handlersQ.async(flags: .barrier) { self.downloadCompletionHandlers[id] = handler }
    }
    
    func downloadProgressHandler(for id: Int) -> ((Double) -> Void)? {
        handlersQ.sync { downloadProgressHandlers[id] }
    }
    
    func downloadCompletionHandler(for id: Int) -> ((Result<URL, Error>) -> Void)? {
        handlersQ.sync { downloadCompletionHandlers[id] }
    }
    
    func clearDownloadHandlers(for id: Int) {
        handlersQ.async(flags: .barrier) {
            self.downloadProgressHandlers.removeValue(forKey: id)
            self.downloadCompletionHandlers.removeValue(forKey: id)
        }
    }

    // Upload handlers
    func setUploadProgressHandler(_ handler: ((Double) -> Void)?, for id: Int) {
        handlersQ.async(flags: .barrier) { self.uploadProgressHandlers[id] = handler }
    }
    
    func setUploadCompletionHandler(_ handler: ((Result<URL, Error>) -> Void)?, for id: Int) {
        handlersQ.async(flags: .barrier) { self.uploadCompletionHandlers[id] = handler }
    }
    
    func uploadProgressHandler(for id: Int) -> ((Double) -> Void)? {
        handlersQ.sync { uploadProgressHandlers[id] }
    }
    
    func uploadCompletionHandler(for id: Int) -> ((Result<URL, Error>) -> Void)? {
        handlersQ.sync { uploadCompletionHandlers[id] }
    }
    
    func setUploadResponseData(_ data: Data, for id: Int) {
        handlersQ.async(flags: .barrier) { self.uploadResponseData[id] = data }
    }
    
    func takeUploadResponseData(for id: Int) -> Data {
        handlersQ.sync { uploadResponseData[id] ?? Data() }
    }
    
    func clearUploadHandlers(for id: Int) {
        handlersQ.async(flags: .barrier) {
            self.uploadCompletionHandlers.removeValue(forKey: id)
            self.uploadProgressHandlers.removeValue(forKey: id)
            self.uploadResponseData.removeValue(forKey: id)
        }
    }
    
    // MARK: - Upload (with Matrix support)
    
    func upload(to urlPath: String, data: Data) async -> APIResult<String> {
        guard let url = URL(string: urlPath) else { return .unsuccess(.invalidURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        do {
            let (_, response) = try await session.upload(for: request, from: data)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return .unsuccess(.fileUploadFailed)
            }
            return .success("Upload successful")
        } catch {
            return .unsuccess(.fileUploadFailed)
        }
    }
    
    func upload(path: String, fileURL: URL, mimeType: String, onProgress: ((Double) -> Void)? = nil) async -> APIResult<URL> {
        guard let url = URL(string: path) else {
            print("[HttpClient] Invalid upload URL: \(path)")
            return .unsuccess(.invalidURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30000
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        addHeaders(to: &request)
        
        guard let mediaData = try? Data(contentsOf: fileURL) else {
            print("[HttpClient] Failed to read file data for upload: \(fileURL)")
            return .unsuccess(.fileUploadFailed)
        }
        
        // --- PRINT THE REQUEST ---
        print("[HttpClient] Upload Request")
        print("[HttpClient] └─ URL: \(request.url?.absoluteString ?? "-")")
        print("[HttpClient] └─ Method: \(request.httpMethod ?? "-")")
        print("[HttpClient] └─ Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("[HttpClient] └─ File: \(fileURL.lastPathComponent) | size: \(mediaData.count) bytes")
        let maxPreview = 128
        let preview = mediaData.prefix(maxPreview)
        print("[HttpClient] └─ Data Preview: \(preview.map { String(format: "%02x", $0) }.joined(separator: " ")) ...")
        // ------------------------
        
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                print("[HttpClient] Self was deallocated before starting upload")
                continuation.resume(returning: .unsuccess(.unknown))
                return
            }
            let task = self.session.uploadTask(with: request, from: mediaData)
            let taskId = task.taskIdentifier
            
            if let onProgress = onProgress {
                self.setUploadProgressHandler({ progress in
                    print("[HttpClient] Upload progress [\(taskId)]: \(String(format: "%.2f", progress * 100))%")
                    onProgress(progress)
                }, for: taskId)
            }
            
            self.setUploadCompletionHandler({ result in
                self.clearUploadHandlers(for: taskId)
                switch result {
                case .success(let url):
                    print("[HttpClient] Upload succeeded! URL: \(url)")
                    continuation.resume(returning: .success(url))
                case .failure(let error):
                    print("[HttpClient] Upload failed! Error: \(error.localizedDescription)")
                    continuation.resume(returning: .unsuccess(.serverError))
                }
            }, for: taskId)
            
            print("[HttpClient] Upload task [\(taskId)] resume.")
            task.resume()
        }
    }


    // MARK: - Download (with progress)
    func downloadMedia(
        path: String,
        onProgress: ((Double) -> Void)? = nil
    ) async -> APIResult<URL> {
        guard let url = URL(string: path) else {
            print("[HttpClient] Invalid download URL")
            return .unsuccess(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        return await withCheckedContinuation { continuation in
            let task = session.downloadTask(with: request)
            let taskId = task.taskIdentifier

            // Store the progress callback
            if let onProgress = onProgress {
                self.setDownloadProgressHandler(onProgress, for: taskId)
            }

            // Store the completion callback
            self.setDownloadCompletionHandler({ result in
                self.clearDownloadHandlers(for: taskId)
                switch result {
                case .success(let tempURL):
                    continuation.resume(returning: .success(tempURL))
                case .failure(let error):
                    print("[HttpClient] Download failed: \(error.localizedDescription)")
                    continuation.resume(returning: .unsuccess(.fileDownloadFailed))
                }
            }, for: taskId)

            task.resume()
        }
    }

    // MARK: - Standard HTTP Methods
    func get<T: Decodable>(_ path: String, response: T.Type) async -> APIResult<T> {
        await request(path, method: "GET", body: nil, expecting: response)
    }

    func post<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R> {
        guard let encoded = try? JSONEncoder().encode(body) else {
            return .unsuccess(.invalidCredentials)
        }
        return await request(path, method: "POST", body: encoded, expecting: expecting)
    }

    func put<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R> {
        guard let encoded = try? JSONEncoder().encode(body) else {
            return .unsuccess(.decodingError)
        }
        return await request(path, method: "PUT", body: encoded, expecting: expecting)
    }

    func delete<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R> {
        guard let encoded = try? JSONEncoder().encode(body) else {
            return .unsuccess(.decodingError)
        }
        return await request(path, method: "DELETE", body: encoded, expecting: expecting)
    }

    // MARK: - Internal Request Helper
    // MARK: - Internal Request Helper
    private func request<T: Decodable>(
        _ path: String,
        method: String,
        body: Data? = nil,
        expecting: T.Type
    ) async -> APIResult<T> {
        guard let url = URL(string: path) else { return .unsuccess(.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30000
        addHeaders(to: &request)
        request.httpBody = body
        if method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            // 1. make the call
            let (data, response) = try await session.data(for: request)
            
            // 2. validate status
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                print("[HttpClient] HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[HttpClient] Error Response Body: \(responseString)")
                }
                
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    let errorMessage = (apiError.message ?? apiError.error ?? "").lowercased()
                    return .unsuccess(.custom(errorMessage))
                }
                return .unsuccess(.serverError)
            }
            
            // 3. try to decode
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return .success(decoded)
            } catch {
                // decoding failed but we still have raw data
                print("[HttpClient] Decoding failed for \(path): \(error)")
                
                if let raw = String(data: data, encoding: .utf8) {
                    print("[HttpClient] Raw Response Body:")
                    print(raw)
                } else {
                    print("[HttpClient] Raw Response Body: <non-utf8 \(data.count) bytes>")
                }
                
                // optional: pretty-print JSON if it is JSON-ish
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("[HttpClient] Pretty JSON:")
                    print(prettyString)
                }
                
                return .unsuccess(.serverError)
            }
            
        } catch {
            // network/transport-level error
            print("[HttpClient] Network error for \(path): \(error)")
            if let urlError = error as? URLError {
                print("[HttpClient] URLError: \(urlError)")
            }
            return .unsuccess(.serverError)
        }
    }

    // MARK: - Header Helpers
    private func addHeaders(to request: inout URLRequest) {
        if isMatrixClient {
            if let token = tokenProvider.matrixToken, !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        } else {
            if let token = tokenProvider.accessToken, !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
    }
}

extension HttpClient {
    func postMultipart<R>(_ path: String, fileUploadRequest: FileUploadRequest, expecting: R.Type) async -> APIResult<R> where R : Decodable {
        guard let url = URL(string: path) else { return .unsuccess(.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30000
        addHeaders(to: &request)  // Adds Authorization header

        // ✅ Add matrix-access-token explicitly
        if let matrixToken = tokenProvider.matrixToken, !matrixToken.isEmpty {
            request.setValue(matrixToken, forHTTPHeaderField: "matrix-access-token")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fieldName: String = "file"
        let fileName: String = fileUploadRequest.filename
        var mimeType: String = fileUploadRequest.mimeType
        var uploadData = fileUploadRequest.file
        
        print("Final upload size: \(uploadData.count / 1024 / 1024) MB")

        // --- Build body ---
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(uploadData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // --- Perform request ---
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[HttpClient] Upload failed response: \(responseString)")
                }
                return .unsuccess(.serverError)
            }
            let decoded = try JSONDecoder().decode(R.self, from: data)
            return .success(decoded)
        } catch {
            print("[HttpClient] Multipart upload error: \(error.localizedDescription)")
            return .unsuccess(.serverError)
        }
    }
}

// MARK: - Session Delegate

final class HttpClientSessionDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDataDelegate {
    weak var owner: HttpClient?

    // SSL Pinning (implement as needed)
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // TODO: Add pinning logic here if needed. Default: system handling.
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: Download Progress
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let owner = owner, totalBytesExpectedToWrite > 0 else { return }
        // Read handler atomically
        guard let handler = owner.downloadProgressHandler(for: downloadTask.taskIdentifier) else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { handler(progress) }
    }

    // MARK: Download Completion
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let owner = owner else { return }
        let taskId = downloadTask.taskIdentifier
        let fm = FileManager.default
        let dest = destinationURL(for: downloadTask, tempURL: location)
        
        if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
        do {
            try fm.moveItem(at: location, to: dest)
            DispatchQueue.main.async {
                owner.downloadCompletionHandler(for: taskId)?(.success(dest))
                owner.clearDownloadHandlers(for: taskId)
            }
        } catch {
            do {
                try fm.copyItem(at: location, to: dest)
                DispatchQueue.main.async {
                    owner.downloadCompletionHandler(for: taskId)?(.success(dest))
                    owner.clearDownloadHandlers(for: taskId)
                }
            } catch {
                DispatchQueue.main.async {
                    owner.downloadCompletionHandler(for: taskId)?(.failure(error))
                    owner.clearDownloadHandlers(for: taskId)
                }
            }
        }
    }

    // MARK: Download Failure
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let owner = owner else { return }
        let taskId = task.taskIdentifier
        defer { owner.clearUploadHandlers(for: taskId) }
        
        guard let completion = owner.uploadCompletionHandler(for: taskId) else { return }
        
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let response = task.response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            completion(
                .failure(
                    NSError(
                        domain: "HttpClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Upload failed"]
                    )
                )
            )
            return
        }
        
        let responseData = owner.takeUploadResponseData(for: taskId)
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let contentUri = json["content_uri"] as? String,
           let url = URL(string: contentUri) {
            completion(.success(url))
        } else {
            completion(
                .failure(
                    NSError(
                        domain: "HttpClient",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Missing/invalid content_uri"]
                    )
                )
            )
        }
    }
    
    // MARK: Upload Progress
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0, let owner = owner else { return }
        if let handler = owner.uploadProgressHandler(for: task.taskIdentifier) {
            let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
            DispatchQueue.main.async { handler(progress) }
        }
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        owner?.setUploadResponseData(data, for: dataTask.taskIdentifier)
    }
    
    private func destinationURL(for task: URLSessionDownloadTask, tempURL: URL) -> URL {
        let fm = FileManager.default
        let caches = try! fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = caches.appendingPathComponent("MediaCache", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        // Base name: hash of original request URL to avoid collisions/long names
        let original = task.originalRequest?.url?.absoluteString ?? UUID().uuidString
        var base = sha256(original)

        // Figure out extension:
        // 1) from suggested filename
        // 2) else from MIME type
        // 3) else fall back to tempURL’s pathExtension or none
        var ext = (task.response as? HTTPURLResponse)?.suggestedFilename.flatMap { URL(fileURLWithPath: $0).pathExtension }
        if (ext == nil || ext!.isEmpty),
           let mime = task.response?.mimeType,
           let ut = UTType(mimeType: mime),
           let preferred = ut.preferredFilenameExtension {
            ext = preferred
        }
        if (ext == nil || ext!.isEmpty) {
            let tempExt = tempURL.pathExtension
            ext = tempExt.isEmpty ? nil : tempExt
        }

        if let ext, !ext.isEmpty {
            base += ".\(ext)"
        }

        return folder.appendingPathComponent(base, isDirectory: false)
    }
}
