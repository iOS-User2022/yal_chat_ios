//
//  OTPBoxView.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//

import SwiftUI

struct OTPBoxView: View {
    @Binding var digit: String
    var index: Int
    var focusedIndex: FocusState<Int?>.Binding
    
    var body: some View {
        TextField("-", text: $digit)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .padding(.vertical, 16)
            .frame(width: 41, height: 48)
            .background(Design.Color.lightGrayBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 0)
            .overlay(content: {
                RoundedRectangle(cornerRadius: 16)
                .inset(by: 0.5)
                .stroke(Color(red: 0.37, green: 0.24, blue: 0.72), lineWidth: 1)
                .opacity(0.3)
            })
            .focused(focusedIndex, equals: index)
            .onChange(of: digit) { newDigit in
                // Allow only a single character
                if newDigit.count > 1 {
                    digit = String(newDigit.prefix(1))
                }

                // Auto-advance focus if character is valid and not last box
                if !newDigit.isEmpty && index < 5 {
                    DispatchQueue.main.async {
                        focusedIndex.wrappedValue = index + 1
                    }
                }
            }
    }
}

