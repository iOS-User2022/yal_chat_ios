//
//  CallLogView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct CallLogView: View {
    @State private var search = ""
    @State private var selectedFilter: CallFilter = .all
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaInsets = geometry.safeAreaInsets
            
            VStack(spacing: 0) {
                SearchBarView(placeholder: "Search names & more", text: $search)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                
                Spacer().frame(height: 20)
                
                TabFiltersView(filters: CallFilter.allCases, selectedFilter: $selectedFilter)
                
                ScrollView {
                    VStack(spacing: 16) {
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // padding for tab bar spacing
                    .background(Design.Color.chatBackground)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72 + safeAreaInsets.bottom)
                }
            }
            .background(Design.Color.chatBackground)
        }
    }
}
