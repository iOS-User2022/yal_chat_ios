//
//  ContactLite.swift
//  YAL
//
//  Created by Vishal Bhadade on 13/11/25.
//

import Foundation
import Contacts
import SwiftUI


public struct ContactLite: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var id: String { phoneNumber }

    public var userId: String?
    public var fullName: String?
    public var imageData: Data?
    public var phoneNumber: String
    public var emailAddresses: [String]
    public var imageURL: String?
    public var avatarURL: String?
    public var displayName: String?
    public var about: String?
    public var dob: String?
    public var gender: String?
    public var profession: String?
    public var isBlocked: Bool
    public var isSynced: Bool
    public var isOnline: Bool
    public var lastSeen: Int?
    public var randomeProfileColor: Color? = randomBackgroundColor() // not codable

    // Coding keys: exclude randomeProfileColor
    private enum CodingKeys: String, CodingKey {
        case userId, fullName, imageData, phoneNumber, emailAddresses, imageURL, avatarURL,
             displayName, about, dob, gender, profession, isBlocked, isSynced, isOnline, lastSeen
    }

    // Designated init
    public init(
        userId: String? = nil,
        fullName: String? = nil,
        imageData: Data? = nil,
        phoneNumber: String,
        emailAddresses: [String] = [],
        imageURL: String? = nil,
        avatarURL: String? = nil,
        displayName: String? = nil,
        about: String? = nil,
        dob: String? = nil,
        gender: String? = nil,
        profession: String? = nil,
        isBlocked: Bool = false,
        isSynced: Bool = false,
        isOnline: Bool = false,
        lastSeen: Int? = nil,
        randomeProfileColor: Color? = nil
    ) {
        self.userId = userId
        self.fullName = fullName
        self.imageData = imageData
        self.phoneNumber = phoneNumber
        self.emailAddresses = emailAddresses
        self.imageURL = imageURL
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.about = about
        self.dob = dob
        self.gender = gender
        self.profession = profession
        self.isBlocked = isBlocked
        self.isSynced = isSynced
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.randomeProfileColor = randomeProfileColor ?? randomBackgroundColor()
    }

    // Custom Decodable: ignore color, set a fresh one
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId         = try c.decodeIfPresent(String.self, forKey: .userId)
        self.fullName       = try c.decodeIfPresent(String.self, forKey: .fullName)
        self.imageData      = try c.decodeIfPresent(Data.self,   forKey: .imageData)
        self.phoneNumber    = try c.decode(String.self,          forKey: .phoneNumber)
        self.emailAddresses = try c.decodeIfPresent([String].self, forKey: .emailAddresses) ?? []
        self.imageURL       = try c.decodeIfPresent(String.self, forKey: .imageURL)
        self.avatarURL      = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        self.displayName    = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.about          = try c.decodeIfPresent(String.self, forKey: .about)
        self.dob            = try c.decodeIfPresent(String.self, forKey: .dob)
        self.gender         = try c.decodeIfPresent(String.self, forKey: .gender)
        self.profession     = try c.decodeIfPresent(String.self, forKey: .profession)
        self.isBlocked      = try c.decodeIfPresent(Bool.self,   forKey: .isBlocked) ?? false
        self.isSynced       = try c.decodeIfPresent(Bool.self,   forKey: .isSynced)  ?? false
        self.isOnline       = try c.decodeIfPresent(Bool.self,   forKey: .isOnline)  ?? false
        self.lastSeen       = try c.decodeIfPresent(Int.self,    forKey: .lastSeen)
        self.randomeProfileColor = randomBackgroundColor()
    }

    // Custom Encodable: omit color
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(userId,         forKey: .userId)
        try c.encodeIfPresent(fullName,       forKey: .fullName)
        try c.encodeIfPresent(imageData,      forKey: .imageData)
        try c.encode(phoneNumber,             forKey: .phoneNumber)
        try c.encode(emailAddresses,          forKey: .emailAddresses)
        try c.encodeIfPresent(imageURL,       forKey: .imageURL)
        try c.encodeIfPresent(avatarURL,      forKey: .avatarURL)
        try c.encodeIfPresent(displayName,    forKey: .displayName)
        try c.encodeIfPresent(about,          forKey: .about)
        try c.encodeIfPresent(dob,            forKey: .dob)
        try c.encodeIfPresent(gender,         forKey: .gender)
        try c.encodeIfPresent(profession,     forKey: .profession)
        try c.encode(isBlocked,               forKey: .isBlocked)
        try c.encode(isSynced,                forKey: .isSynced)
        try c.encode(isOnline,                forKey: .isOnline)
        try c.encodeIfPresent(lastSeen,       forKey: .lastSeen)
    }

    // Keep Hashable/Equatable independent of Color
    public static func == (lhs: ContactLite, rhs: ContactLite) -> Bool {
        lhs.userId?.formattedMatrixUserId == rhs.userId?.formattedMatrixUserId
        && lhs.phoneNumber == rhs.phoneNumber
        && lhs.fullName == rhs.fullName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(userId?.formattedMatrixUserId ?? "")
        hasher.combine(phoneNumber)
    }
}

// MARK: - ContactLite Updaters (mirror of ContactModel)
extension ContactLite {
    
    public mutating func updatePresence(
        isOnline: Bool,
        lastSeen: Int?,
        avatarURL: String? = nil,
        statusMessage: String? = nil
    ) {
        self.isOnline = isOnline
        if let lastSeenMsAgo = lastSeen {
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            self.lastSeen = nowMs - lastSeenMsAgo
        } else {
            self.lastSeen = nil
        }
        if let avatarURL { self.avatarURL = avatarURL }
        if let statusMessage { self.about = statusMessage }
    }

    // Normalize and set MXID/userId (adjust formatter to your canonical logic if needed).
    public mutating func setUserId(_ userId: String) {
        self.userId = userId.formattedMatrixUserId
    }

    public mutating func setImageURL(imageURL: String) {
        self.imageURL = imageURL
    }

    public mutating func setDisplayName(displayName: String) {
        self.displayName = displayName
    }

    public mutating func setIsOnline(isOnline: Bool) {
        self.isOnline = isOnline
    }

    // Accepts milliseconds-ago and stores absolute ms since epoch.
    public mutating func setLastSeen(lastSeen: Int) {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        self.lastSeen = nowMs - lastSeen
    }

    public mutating func setAvatarURL(avatarURL: String) {
        self.avatarURL = avatarURL
    }

    public mutating func setStatusMessage(statusMessage: String) {
        self.about = statusMessage
    }
}

// MARK: - ContactLite helper
extension ContactLite {

    static func from(contact: CNContact, phoneNumber e164: String) -> ContactLite {
        let fullName: String = {
            if let formatted = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !formatted.isEmpty
            { return formatted }

            let simple = "\(contact.givenName) \(contact.familyName)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return simple.isEmpty ? e164 : simple
        }()

        var model = ContactLite(userId: "", fullName: fullName, phoneNumber: e164)

        // display name (prefer nickname)
        if contact.isKeyAvailable(CNContactNicknameKey), !contact.nickname.isEmpty {
            model.displayName = contact.nickname
        }

        // emails
        if contact.isKeyAvailable(CNContactEmailAddressesKey) {
            model.emailAddresses = contact.emailAddresses
                .map { String($0.value) }
                .filter { !$0.isEmpty }
        }

        // image: prefer thumbnail to keep things light; fall back to full image if thumb is missing
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey),
           let thumb = contact.thumbnailImageData, !thumb.isEmpty {
            model.imageData = thumb
        } else if contact.isKeyAvailable(CNContactImageDataKey),
                  let full = contact.imageData, !full.isEmpty {
            model.imageData = full
        }

        model.isSynced = false
        return model
    }
}

extension ContactLite {
    static func fromModel(_ m: ContactModel) -> ContactLite {
        let uid = m.userId?.formattedMatrixUserId
        return ContactLite(
            userId: uid,
            fullName: m.fullName,
            imageData: m.imageData,
            phoneNumber: m.phoneNumber,
            emailAddresses: m.emailAddresses,
            imageURL: m.imageURL,
            avatarURL: m.avatarURL ?? m.imageURL,   // prefer avatarURL; fallback to imageURL
            displayName: m.displayName,
            about: m.statusMessage,
            dob: m.dob,
            gender: m.gender,
            profession: m.profession,
            isBlocked: m.isBlocked,
            isSynced: m.isSynced,
            isOnline: m.isOnline,
            lastSeen: m.lastSeen,
            randomeProfileColor: m.randomeProfileColor
        )
    }
}
