//
//  String+Extension.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import Foundation

private let phoneRegexPatterns: [String: String] = [
    "US": #"^(\d{3})[- ]?(\d{3})[- ]?(\d{4})$"#,
    "UK": #"^\+?44\d{10}$"#,
    "IN": #"^\+?91[- ]?\d{10}$"#
]

// Helper to make Base64 URL-safe if needed
private func base64URLSafe(_ s: String, padded: Bool) -> String {
    var out = s
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
    if !padded {
        out = out.replacingOccurrences(of: "=", with: "")
    }
    return out
}

extension String {
    func isValidPhoneNumber(forRegion region: String = "IN") -> Bool {
        guard let pattern = phoneRegexPatterns[region] else { return false }
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: self)
    }
    
    var isValidName: Bool {
        let nameRegex = #"^[A-Za-zÀ-ÖØ-öø-ÿ'\- ]{1,50}$"#
        return NSPredicate(format: "SELF MATCHES %@", nameRegex).evaluate(with: self)
    }
    
    func formattedDateFromISO() -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy"
        displayFormatter.locale = Locale(identifier: "en_US")
        
        // Try decoding with fractional seconds
        if let date = isoFormatter.date(from: self) {
            return displayFormatter.string(from: date)
        }
        
        // Fallback without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: self) {
            return displayFormatter.string(from: date)
        }
        
        return self // or "Invalid Date"
    }
    
    // e.g. "@alice:yal.chat" -> "alice", "alice" -> "alice"
    var trimmedMatrixUserId: String {
        let s = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("@") else { return s }
        let withoutAt = s.dropFirst()
        // split only once; homeserver (with optional :port) stays intact
        let parts = withoutAt.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.first.map(String.init) ?? String(withoutAt)
    }
    
    /// Returns true if string looks like a Matrix user id: "@localpart:homeserver[:port]"
    var isMatrixUserId: Bool {
        // Pragmatic regex (allows common localpart chars and optional :port)
        let pattern = #"^@[A-Za-z0-9._=\-/]+:[A-Za-z0-9.\-]+(?::\d+)?$"#
        return self.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Returns true if it's a Matrix ID for the given homeserver (case-insensitive).
    func isMatrixUserId(forHomeServer expected: String) -> Bool {
        guard self.isMatrixUserId else { return false }
        return (self.matrixHomeServer?.lowercased() == expected.lowercased())
    }
    
    /// Extracts "@localpart:homeserver" parts (nil if not a Matrix ID).
    var matrixLocalPart: String? {
        guard self.hasPrefix("@") else { return nil }
        let s = self.dropFirst()
        let parts = s.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.first.map(String.init)
    }
    
    var matrixHomeServer: String? {
        guard self.hasPrefix("@") else { return nil }
        let s = self.dropFirst()
        let parts = s.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return String(parts[1])
    }
    
    /// Formats with current session homeserver if needed.
    /// If already a full Matrix ID, returns self unchanged.
    var formattedMatrixUserId: String {
        let raw = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isMatrixUserId { return raw }
        
        let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)
        let hs = authSession?.homeServer ?? "yal.chat"
        
        let local = raw.trimmedMatrixUserId
        guard !local.isEmpty else { return raw } // avoid producing "@:hs"
        return "@\(local):\(hs)"
    }
    
    /// Ensures the ID is formatted *and* bound to the given homeserver.
    /// If it's already formatted for another HS, it re-writes to the expected one.
    func ensuringHomeServer(_ expectedHomeServer: String) -> String {
        let raw = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isMatrixUserId(forHomeServer: expectedHomeServer) { return raw }
        let local = raw.trimmedMatrixUserId
        guard !local.isEmpty else { return raw }
        return "@\(local):\(expectedHomeServer)"
    }
    
    // MARK: - HEX → Data / Base64 utilities (for APNs token etc.)
    
    // Returns Data from a hex string. Accepts spaces and angle brackets.
    var hexData: Data? {
        // Strip spaces and angle brackets often seen in printed device tokens
        let hex = self
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard hex.count % 2 == 0, !hex.isEmpty else { return nil }
        
        var data = Data(capacity: hex.count / 2)
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard next <= hex.endIndex,
                  let b = UInt8(hex[idx..<next], radix: 16) else { return nil }
            data.append(b)
            idx = next
        }
        return data
    }
    
    // Standard Base64 from a hex string (e.g., APNs token hex → Base64)
    var base64FromHex: String? {
        guard let d = self.hexData else { return nil }
        return d.base64EncodedString()
    }
    
    // URL-safe Base64 from a hex string. Set `padded` to true if the receiver expects '=' padding.
    func base64URLSafeFromHex(padded: Bool = false) -> String? {
        guard let standard = self.base64FromHex else { return nil }
        return base64URLSafe(standard, padded: padded)
    }
}

var thisMessageWasDeleted = "⊘ This message was deleted."
