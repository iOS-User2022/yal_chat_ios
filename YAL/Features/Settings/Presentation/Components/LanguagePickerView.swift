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
        ZStack {
            VStack(spacing: 0) {

                // MARK: — Header Row
                HStack {
                    Text("Select Language")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 25)
                .padding(.bottom, 16)

              
                // MARK: — Language Option
                languageOptionRow(label: "English (Default)", tag: "en")
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 0)

                
                // Solid thin divider under header
                Rectangle()
                    .fill(Color(hex: "#0A171F"))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                
                // MARK: — Coming Soon text
                Text("We are adding more languages soon")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // MARK: — Reset Default Button
                Button(action: {
                    selection = "en"
                    withAnimation { isPresented = false }
                }) {
                    Text("Reset Default")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 150)
                        .frame(height: 40)
                        .background(Design.Color.appGradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "#202D35"))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Language Option Row
    @ViewBuilder
    private func languageOptionRow(label: String, tag: String) -> some View {
        Button {
            selection = tag
        } label: {
            HStack(spacing: 14) {
                // Radio button from asset images
                Image(selection == tag ? "radioButton" : "radio")
                    .resizable()
                    .frame(width: 20, height: 20)

                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()
            }
            .padding(.horizontal, 45)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
