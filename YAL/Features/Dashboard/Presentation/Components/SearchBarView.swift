//
//  SearchBarView.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI

struct SearchBarView: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image("search")

            TextField(placeholder, text: $text)
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.navy)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Design.Color.lighterGrayBackground)
        .cornerRadius(12)
    }
}
