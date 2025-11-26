//
//  ContactSectionedList.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct ContactSectionedList: View {
    let sections: [ContactSection]
    
    init(sections: [ContactSection]) {
        self.sections = sections
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().separatorInset = .init()

    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            
            List {
                ForEach(sections) { section in
                    Section(header: Text(section.letter)) {
                        ForEach(section.contacts) { contact in
                            ContactRowView(contact: contact)
                                .listRowBackground(Design.Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72 + safeAreaInsets.bottom) // Tab bar height
            }
        }
    }
}
