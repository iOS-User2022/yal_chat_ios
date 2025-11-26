//
//  SelectContactSection.swift
//  YAL
//
//  Created by Vishal Bhadade on 12/05/25.
//


import SwiftUI
import Contacts

// Section for grouped contacts based on the first letter of the name and presence of userId
struct SelectContactSection: Identifiable {
    var id: String { letter }
    let letter: String
    let contacts: [ContactLite]
    
    static func from(contactModels: [ContactLite]) -> [SelectContactSection] {
        // Group contacts into two categories: userId exists and userId does not exist
        let groupedByUserId = Dictionary(grouping: contactModels) { contact -> Bool in
            // Check if the userId exists
            return contact.userId != nil
        }
        
        // Now, create sections for contacts with userId and without userId
        var sections: [SelectContactSection] = []
        
        // Contacts with userId
        if let withUserId = groupedByUserId[true] {
            let groupedWithUserId = groupAndSortContacts(contactModels: withUserId)
            sections.append(contentsOf: groupedWithUserId)
        }
        
        // Contacts without userId
        if let withoutUserId = groupedByUserId[false] {
            let groupedWithoutUserId = groupAndSortContacts(contactModels: withoutUserId)
            sections.append(contentsOf: groupedWithoutUserId)
        }
        
        // Sort the sections first by whether userId exists and then by letter
        return sections.sorted { $0.letter < $1.letter }
    }
    
    // Helper function to group contacts lexicographically by first character of the name
    private static func groupAndSortContacts(contactModels: [ContactLite]) -> [SelectContactSection] {
        let grouped = Dictionary(grouping: contactModels) { contact -> String in
            // Use the first letter of the full name for grouping
            return String(contact.fullName?.prefix(1) ?? "").uppercased()
        }
        
        return grouped.map { key, value in
            SelectContactSection(letter: key, contacts: value.sorted { $0.fullName ?? "" < $1.fullName ?? "" })
        }
        .sorted { $0.letter < $1.letter }
    }
}
