//
//  BaseRowView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI

struct BaseRowView<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        HStack {
            content()
        }
        .padding(.vertical, 8)
    }
}
