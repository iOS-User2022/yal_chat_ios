//
//  LanguagePickerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/04/25.
//


import SwiftUI

struct LanguagePickerView: View {
    @Binding var isPresented: Bool
    @State private var selection: String = "en"
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: Header
            HStack {
                Text("Select Language")
                    .font(Design.Font.heavy(16))
                    .foregroundColor(Design.Color.primaryText)
                Spacer()
                Button {
                    withAnimation { isPresented = false }
                } label: {
                    Text("Close")
                        .font(Design.Font.heavy(14))
                        .foregroundColor(Design.Color.navy)
                        .underline(true, color: Design.Color.navy)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)


            // MARK: Options
            RadioRow(label: "English (Default)", tag: "en", selection: $selection)
//            RadioRow(label: "Hindi", tag: "hd", selection: $selection)
//            RadioRow(label: "Español", tag: "es", selection: $selection)
//            RadioRow(label: "Marathi", tag: "mr", selection: $selection)

            // Future languages…
            // RadioRow(label: "Español", tag: "es", selection: $selection)
            // …
            
            Text("We are adding more languages soon")
                .font(Design.Font.regular(12))
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                .padding(.horizontal, 20)
            
            // MARK: Reset Button
            Button(action: {
                selection = "en"
                withAnimation { isPresented = false }
            }) {
                HStack(alignment: .center, spacing: 8) {
                    Image("reset")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text("Reset Default")
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.navy)
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .padding(.horizontal, 20)
                .background(Design.Color.lightWhiteBackground)
                .cornerRadius(8)
            }

        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 40)
        // Fixed height to match your design
        .frame(maxWidth: 340, minHeight: 200)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(radius: 20)
    }
}

// Simple radio-button row
fileprivate struct RadioRow: View {
    let label: String
    let tag: String
    @Binding var selection: String

    var body: some View {
        Button {
            selection = tag
        } label: {
            VStack(alignment: .center, spacing: 0) {
                HStack(spacing: 12) {
                    Image(selection == tag ? "radio-selected" : "radio")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(label)
                        .font(Design.Font.regular(14))
                        .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(Design.Color.primaryText.opacity(0.04))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}
