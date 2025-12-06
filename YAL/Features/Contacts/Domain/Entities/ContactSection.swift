//
//  ContactSection.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import Contacts

struct ContactSection: Identifiable {
    var id: String { letter }
    let letter: String
    let contacts: [ContactLite]
    
    static func from(contactModels: [ContactLite]) -> [ContactSection] {
        func normalizedPhone(_ s: String) -> String {
            s.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        }
        let filtered = contactModels.compactMap { c -> ContactLite? in
            let phone = normalizedPhone(c.phoneNumber)
            return phone.isEmpty ? nil : c
        }

        var byPhone: [String: ContactLite] = [:]
        for c in filtered {
            byPhone[normalizedPhone(c.phoneNumber)] = c
        }
        let uniqueContacts = Array(byPhone.values)

        func bestName(_ c: ContactLite) -> String {
            if let n = c.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return n }
            if let d = c.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty { return d }
            return c.phoneNumber  // safe now because we've filtered for non-empty numbers
        }

        func sectionLetter(for c: ContactLite) -> String {
            let s = bestName(c).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let ch = s.uppercased().first else { return "#" }
            let L = String(ch)
            return (L >= "A" && L <= "Z") ? L : "#"
        }

        let grouped = Dictionary(grouping: uniqueContacts, by: sectionLetter)

        let sections = grouped.map { letter, bucket -> ContactSection in
            let sorted = bucket.sorted {
                let a = bestName($0)
                let b = bestName($1)
                let ord = a.localizedCaseInsensitiveCompare(b)
                return ord == .orderedAscending || (ord == .orderedSame && normalizedPhone($0.phoneNumber) < normalizedPhone($1.phoneNumber))
            }
            return ContactSection(letter: letter, contacts: sorted)
        }

        // Sort sections A–Z, then '#'
        return sections.sorted { lhs, rhs in
            if lhs.letter == "#" { return false }
            if rhs.letter == "#" { return true }
            return lhs.letter < rhs.letter
        }
    }
}
