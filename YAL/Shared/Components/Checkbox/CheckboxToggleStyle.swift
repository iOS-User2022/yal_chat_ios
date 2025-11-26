//
//  CheckboxToggleStyle.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 10) {
                Image(configuration.isOn ? "checkbox-selected" : "checkbox")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
                    .border(Design.Color.navy, width: 1)

                configuration.label
                    .foregroundColor(Design.Color.grayText) // or your secondary text color
                    .font(Design.Font.regular(16))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

