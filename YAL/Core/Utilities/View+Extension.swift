//
//  View+Extension.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import SwiftUI

extension View {
    func roundedShadow(cornerRadius: CGFloat = 8, shadowRadius: CGFloat = 4) -> some View {
        self.modifier(RoundedShadowModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func underlined(font: Font = .body) -> some View {
        self.modifier(UnderlinedButtonStyle(font: font))
    }
    
    func hideKeyboardOnTap() -> some View {
        self.gesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
    
    @ViewBuilder
    func hidden(isHidden: Bool) -> some View {
        if isHidden {
            self.hidden()
        } else {
            self
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
