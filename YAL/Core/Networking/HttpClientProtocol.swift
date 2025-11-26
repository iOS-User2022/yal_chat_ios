//
//  HttpClientProtocol.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//


import Foundation
import Combine

protocol HttpClientProtocol {
    var isMatrixClient: Bool { get set }
    func get<T: Decodable>(_ path: String, response: T.Type) async -> APIResult<T>
    func post<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R>
    func put<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R>
    func delete<T: Encodable, R: Decodable>(_ path: String, body: T, expecting: R.Type) async -> APIResult<R>
    func upload(to url: String, data: Data) async -> APIResult<String>
    func upload(path: String, fileURL: URL, mimeType: String, onProgress: ((Double) -> Void)?) async -> APIResult<URL>
    func downloadMedia(path: String, onProgress: ((Double) -> Void)?) async -> APIResult<URL>
    func postMultipart<R: Decodable>(_ path: String, fileUploadRequest: FileUploadRequest, expecting: R.Type) async -> APIResult<R>
}

