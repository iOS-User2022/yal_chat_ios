//
//  ProfileField.swift
//  YAL
//
//  Created by Vishal Bhadade on 23/04/25.
//

import SwiftUI

struct ProfileField: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(value)
                        .font(.body.bold())
                        .foregroundColor(.white)
                }
            }
        }
    }
}
