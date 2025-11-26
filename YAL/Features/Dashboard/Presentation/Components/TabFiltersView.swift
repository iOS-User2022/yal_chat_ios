//
//  TabFiltersView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//


import SwiftUI

/// A generic filter tab view that can show filter options like All, Unread, Spam, etc.
struct TabFiltersView<Filter: Hashable & RawRepresentable>: View where Filter.RawValue == String {
    let filters: [Filter]
    @Binding var selectedFilter: Filter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(filters, id: \..self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        VStack(spacing: 11) {
                            Text(filter.rawValue)
                                .font(Design.Font.medium(12))
                                .foregroundColor(selectedFilter == filter ? Design.Color.headingText : Design.Color.grayText)

                            Capsule()
                                .fill(selectedFilter == filter ? Design.Color.headingText : Design.Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 28)
        }
    }
}

// MARK: - Filter Enums

enum ChatFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case chats = "Chats"
    case groups = "Group"
//    case spam = "Spam"
    case favourites = "Favorites"
}

enum SMSFilter: String, CaseIterable {
    case all = "All"
    case personal = "Personal"
    case transactional = "Transactional"
    case promotional = "Promotional"
}

enum GroupFilter: String, CaseIterable {
    case all = "All"
    case myGroups = "My Groups"
    case joined = "Joined"
    case invites = "Invites"
}

enum CallFilter: String, CaseIterable {
    case all = "All"
    case missed = "Missed"
    case incoming = "Incoming"
    case outgoing = "Outgoing"
}

enum ContactFilter: String, CaseIterable {
    case all = "All"
    case frequentlyUsed = "Frequent"
    case recent = "Recent"
    case blocked = "Blocked"
}

#Preview {
    TabFiltersView(filters: ChatFilter.allCases, selectedFilter: .constant(.all))
}
