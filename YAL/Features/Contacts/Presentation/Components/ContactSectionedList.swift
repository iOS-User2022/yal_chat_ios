//
//  ContactSectionedList.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct ContactSectionedList: View {
    let sections: [ContactSection]
    @Binding var navPath: NavigationPath

    init(sections: [ContactSection], navPath: Binding<NavigationPath>) {
        self.sections = sections
        self._navPath = navPath
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().separatorInset = .init()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            
            List {
                ForEach(sections, id: \.letter) { section in
                    Section(header: sectionHeader(section.letter)) {
                        ForEach(section.contacts, id: \.id) { contact in
                            ContactRowView(
                                contact: contact,
                                onProfileTap: {
                                    navigateToContactInfo(contact)
                                }
                            )
                            .listRowBackground(Design.Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72 + safeAreaInsets.bottom)
            }
        }
    }
    
    private func sectionHeader(_ letter: String) -> some View {
        Text(letter)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gray)
    }
    
    private func navigateToContactInfo(_ contact: ContactLite) {
            let primaryEmail = contact.emailAddresses
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? ""
            let contactData = ContactDisplayData(
                name: contact.fullName ?? contact.displayName ?? "Unknown",
                phoneNumber: contact.phoneNumber ?? "",
                email: primaryEmail,
                avatarUrl: contact.avatarURL ?? contact.imageURL
            )
            
            print("🔍 Created contactData: \(contactData.name)")
            navPath.append(ContactNavigation.contactInfo(contact: contactData))
        }
}
