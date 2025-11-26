//
//  ContactModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 03/05/25.
//

import Foundation
import Contacts
import CoreData
import SwiftUI

final class ContactModel: ObservableObject, Identifiable, Hashable, Codable {
    @Published var randomeProfileColor: Color = randomBackgroundColor()
    @Published var fullName: String?
    @Published var phoneNumber: String
    @Published var emailAddresses: [String]
    @Published var imageData: Data?
    @Published var imageURL: String?
    @Published var userId: String?
    @Published var displayName: String?
    @Published var isOnline: Bool
    @Published var lastSeen: Int?
    @Published var avatarURL: String?
    @Published var statusMessage: String?
    @Published var dob: String?
    @Published var gender: String?
    @Published var profession: String?
    @Published var isBlocked: Bool = false
    var isSynced: Bool = false
    
    var id: String { phoneNumber }

    // MARK: - Initializers
    init(contact: CNContact, phoneNumber: String) {
        let name = "\(contact.givenName) \(contact.familyName)"
        self.fullName = name.isEmpty ? phoneNumber : name
        self.phoneNumber = phoneNumber.filter { !$0.isWhitespace }
        self.emailAddresses = contact.emailAddresses.map { $0.value as String }
        self.imageData = contact.imageData
        self.imageURL = nil
        self.userId = nil
        self.displayName = nil
        self.isOnline = false
        self.lastSeen = nil
        self.isOnline = false
        self.lastSeen = nil
        self.avatarURL = nil
        self.statusMessage = nil
    }
    
    init(phoneNumber: String, userId: String, fullName: String? = nil) {
        self.fullName = (fullName?.isEmpty ?? true) ? phoneNumber : fullName ?? phoneNumber
        self.phoneNumber = phoneNumber
        
        self.emailAddresses = nil ?? []
        self.imageData = nil
        self.imageURL = nil
        self.userId = userId
        self.displayName = nil
        self.isOnline = false
        self.lastSeen = nil
        self.isOnline = false
        self.lastSeen = nil
        self.avatarURL = nil
        self.statusMessage = nil
    }
    
    init(
        fullName: String,
        phoneNumber: String,
        emailAddresses: [String] = [],
        imageURL: String? = nil,
        userId: String,
        displayName: String? = nil,
        about: String? = nil,
        dob: String? = nil,
        gender: String? = nil,
        profession: String? = nil
    ) {
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        
        self.emailAddresses = emailAddresses
        self.imageData = nil
        self.imageURL = nil
        self.userId = userId
        self.displayName = displayName
        self.isOnline = false
        self.lastSeen = nil
        self.isOnline = false
        self.lastSeen = nil
        self.avatarURL = imageURL
        self.statusMessage = about
        self.dob = dob
        self.profession = profession
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case fullName
        case phoneNumber
        case emailAddresses
        case imageData
        case imageURL
        case userId
        case displayName
        case isOnline
        case lastSeen
        case avatarURL
        case statusMessage
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fullName = try container.decode(String.self, forKey: .fullName)
        self.phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        self.emailAddresses = try container.decode([String].self, forKey: .emailAddresses)
        self.imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.isOnline = try container.decode(Bool.self, forKey: .isOnline)
        self.lastSeen = try container.decodeIfPresent(Int.self, forKey: .lastSeen)
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        self.statusMessage = try container.decodeIfPresent(String.self, forKey: .statusMessage)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(emailAddresses, forKey: .emailAddresses)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encodeIfPresent(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(statusMessage, forKey: .statusMessage)
    }
        
    
    // MARK: - Updaters
    func updatePresence(isOnline: Bool, lastSeen: Int?, avatarURL: String? = nil, statusMessage: String? = nil) {
        self.isOnline = isOnline
        if let lastSeenMsAgo = lastSeen {
            let now = Int(Date().timeIntervalSince1970 * 1000)
            let lastSeenTimestamp = now - lastSeenMsAgo
            self.lastSeen = lastSeenTimestamp // Store as ms since epoch
        } else {
            self.lastSeen = nil
        }
        self.avatarURL = avatarURL
        self.statusMessage = statusMessage
    }
    
    func setUserId(_ userId: String) {
        self.userId = formatUserId(userId)
    }
    
    func setImageURL(imageURL: String) {
        self.imageURL = imageURL
    }
    
    func setDisplayName(displayName: String) {
        self.displayName = displayName
    }
    
    func setIsOnline(isOnline: Bool) {
        self.isOnline = isOnline
    }
    
    func setLastSeen(lastSeen: Int) {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let lastSeenTimestamp = now - lastSeen
        self.lastSeen = lastSeenTimestamp // Store as ms since epoch
    }

    func setAvatarURL(avatarURL: String) {
        self.avatarURL = avatarURL
    }
    
    func setStatusMessage(statusMessage: String) {
        self.statusMessage = statusMessage
    }
    
    private func formatUserId(_ userId: String) -> String {
        if userId.starts(with: "@") && userId.contains(":") { return userId }
        let session = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)
        return "@\(userId):\(session?.homeServer ?? "yal.chat")"
    }
    
    static func ==(lhs: ContactModel, rhs: ContactModel) -> Bool { lhs.id == rhs.id }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ContactLite -> ContactModel (direct field copy, no lookups)
extension ContactModel {
    static func fromLite(_ lite: ContactLite) -> ContactModel {
        let m = ContactModel(
            phoneNumber: lite.phoneNumber,
            userId: lite.userId ?? "",
            fullName: lite.fullName
        )

        // If lite.userId exists, format it via setUserId(_); else keep it nil.
        if let uid = lite.userId, !uid.isEmpty {
            m.setUserId(uid)   // uses your formatter
        } else {
            m.userId = nil
        }

        // Copy the rest 1:1
        m.fullName       = lite.fullName
        m.emailAddresses = lite.emailAddresses
        m.avatarURL      = lite.avatarURL
        m.imageURL       = lite.avatarURL
        m.displayName    = lite.displayName
        m.statusMessage  = lite.about
        m.dob            = lite.dob
        m.gender         = lite.gender
        m.profession     = lite.profession
        m.isBlocked      = lite.isBlocked
        m.isSynced       = lite.isSynced

        // Presence defaults already false/nil in your inits
        return m
    }
}

extension ContactModel {
    func toLite() -> ContactLite { ContactLite.fromModel(self) }
}
