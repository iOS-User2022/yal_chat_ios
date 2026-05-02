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
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(Design.Font.medium(13))
                            .foregroundColor(
                                selectedFilter == filter
                                ? Design.Color.headingText
                                : Design.Color.grayText
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedFilter == filter
                                        ? Design.Color.white
                                        : Color.clear
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Design.Color.white.opacity(
                                            selectedFilter == filter ? 0 : 0.3
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
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
}

enum ContactFilter: String, CaseIterable {
    case all = "All"
    case frequentlyUsed = "Frequent"
    case recent = "Recent"
    case blocked = "Blocked"
}
