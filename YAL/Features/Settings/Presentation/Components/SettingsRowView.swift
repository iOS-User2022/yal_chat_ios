//
//  SettingsRowView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct SettingsRowView: View {
    let name: String
    let icon: Image?
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            icon?
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(color)

            Text(name)
                .foregroundColor(color)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 12)
    }
}
