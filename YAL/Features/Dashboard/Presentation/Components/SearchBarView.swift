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
                .resizable()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundColor(Design.Color.primaryTextColor).opacity(0.4)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.4)
                }
                
                TextField("", text: $text)
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryTextColor)
            }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Design.Color.primaryTextColor).opacity(0.08)
        )
    }
}
