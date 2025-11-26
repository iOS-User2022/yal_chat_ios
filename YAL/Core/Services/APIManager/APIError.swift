//
//  APIError.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//


import Foundation

//enum APIError: String, Error {
//    case unknown = "Something went wrong."
//    case serverError = "Server error"
//    case notAuthenticated = "Not authenticated"
//    case decodingError = "Failed to decode response."
//    case invalidURL = "Invalid URL"
//    case userExists = "User already exists"
//    case userNotFound = "User not found"
//    case invalidOTP = "Invalid OTP"
//    case noData = "No data received"
//    case fileUploadFailed = "Failed to upload file"
//    case badRequest = "Bad request"
//    case invalidCredentials = "Unauthorized - Invalid credentials"
//    case otpSentAlready = "OTP already sent"
//    case missingRefreshToken = "Please Add refresh token"
//    case invalidRefreshToken = "Invalid refresh token"
//    case unknownError = "Unknown error"
//    case parserError = "Invalid data"
//    case unauthorized = "Unauthorized"
//    case fileDownloadFailed = "File download failed"
//
//}

enum APIError: Error {
    case unknown
    case serverError
    case notAuthenticated
    case decodingError
    case invalidURL
    case userExists
    case userNotFound
    case invalidOTP
    case noData
    case fileUploadFailed
    case badRequest
    case invalidCredentials
    case otpSentAlready
    case missingRefreshToken
    case invalidRefreshToken
    case unknownError
    case parserError
    case unauthorized
    case fileDownloadFailed
    case tooManyRequests
    case custom(String)
    case timeout
}

extension APIError {
    var localizedDescription: String {
        switch self {
        case .unknown:
            return "Something went wrong."
        case .serverError:
            return "Server error"
        case .notAuthenticated:
            return "Not authenticated"
        case .decodingError:
            return "Failed to decode response."
        case .invalidURL:
            return "Invalid URL"
        case .userExists:
            return "User already exists"
        case .userNotFound:
            return "User not found"
        case .invalidOTP:
            return "Invalid OTP"
        case .noData:
            return "No data received"
        case .fileUploadFailed:
            return "Failed to upload file"
        case .badRequest:
            return "Bad request"
        case .invalidCredentials:
            return "Unauthorized - Invalid credentials"
        case .otpSentAlready:
            return "OTP already sent"
        case .missingRefreshToken:
            return "Please add refresh token"
        case .invalidRefreshToken:
            return "Invalid refresh token"
        case .unknownError:
            return "Unknown error"
        case .parserError:
            return "Invalid data"
        case .unauthorized:
            return "Unauthorized"
        case .fileDownloadFailed:
            return "File download failed"
        case .tooManyRequests:
            return "You're sending too many requests. Please try again later."
        case .custom(let message):
            return message
        case .timeout:
            return "Request timed out"
        }
    }
}
