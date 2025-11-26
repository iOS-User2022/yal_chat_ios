//
//  MuteView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 26/09/25.
//

import SwiftUI

struct MuteView: View {
    @State private var selectedOption: String = "8 hours"
    let onConfirm: (MuteDuration) -> Void
    let onCancel: () -> Void
    
    private let options = ["8 hours", "1 week", "Always"]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Mute message notifications")
                    .font(Design.Font.semiBold(16))
                    .foregroundColor(.black)
                
                Text("Other members will not see that you muted this chat. You will still be notified if you are mentioned.")
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.6))
                    .multilineTextAlignment(.leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        HStack {
                            Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(Design.Color.primaryText.opacity(0.6))
                                .onTapGesture { selectedOption = option }
                            
                            Text(option)
                                .font(Design.Font.regular(14))
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.headingDark)
                        }
                        
                        Button(action: {
                            let duration = durationFromOption(selectedOption)
                            onConfirm(duration)
                        }) {
                            Text("Ok")
                                .font(Design.Font.regular(14))
                                .foregroundColor(Design.Color.headingDark)
                        }
                    }
                }

            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}

func durationFromOption(_ option: String) -> MuteDuration {
    switch option {
    case "8 hours":
        return .eightHours
    case "1 week":
        return .oneWeek
    case "Always":
        return .always
    default:
        return .always // Default to "Always" if something unexpected occurs
    }
}
