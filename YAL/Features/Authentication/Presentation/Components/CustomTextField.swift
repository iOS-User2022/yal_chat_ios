//
//  CustomTextField.swift
//  YAL
//
//  Created by Vishal Bhadade on 28/04/25.
//


import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var isReadOnly: Bool = false
    var keyboardType: UIKeyboardType = .default
    var isFocused: FocusState<Bool>.Binding?

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(Design.Color.headingText.opacity(0.7))
                    .font(Design.Font.body)
            )
            .keyboardType(keyboardType)
            .disabled(isReadOnly)
            .font(Design.Font.body)
            .foregroundColor(Design.Color.headingText)
            .frame(height: 22)
            .focused(isFocusedBinding)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Design.Color.navy)
        }
        .padding(.top, 8)
    }

    private var isFocusedBinding: FocusState<Bool>.Binding {
        if let isFocused = isFocused {
            return isFocused
        } else {
            return FocusState<Bool>().projectedValue
        }
    }
}
