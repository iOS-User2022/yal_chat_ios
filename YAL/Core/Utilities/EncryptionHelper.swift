//
//  EncryptionHelper.swift
//  YAL
//
//  Created by Vishal Bhadade on 06/09/25.
//

import CryptoKit
import Foundation

private func canonicalPhone(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.filter(\.isNumber)
    return trimmed.hasPrefix("+") ? "+" + digits : digits
}

func stableContactsHash(_ contacts: [ContactLite]) -> String {
    let numbers = contacts.map { canonicalPhone($0.phoneNumber) }.sorted()
    let joined = numbers.joined(separator: ",")
    let digest = SHA256.hash(data: Data(joined.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

// Helper: SHA256 of a string (for stable filenames)
func sha256(_ s: String) -> String {
    let d = Data(s.utf8)
    let h = SHA256.hash(data: d)
    return h.compactMap { String(format: "%02x", $0) }.joined()
}
