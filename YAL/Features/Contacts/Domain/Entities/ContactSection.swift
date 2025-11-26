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
        let grouped = Dictionary(grouping: contactModels) { contact -> String in
            // Use the first letter of the full name for grouping
            return contact.fullName?.prefix(1).uppercased() ?? ""
        }
        
        return grouped.map { key, value in
            ContactSection(letter: key, contacts: value.sorted { $0.fullName ?? "" < $1.fullName ?? "" })
        }
        .sorted { $0.letter < $1.letter }
    }
}
