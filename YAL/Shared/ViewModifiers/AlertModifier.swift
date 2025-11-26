//
//  OkAlertModifier.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

struct AlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let title: String
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $isPresented) {
                Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("Okay"), action: {
                        onDismiss?()
                    })
                )
            }
    }
}

extension View {
    func okAlert(isPresented: Binding<Bool>, message: String, title: String = "", onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(AlertModifier(isPresented: isPresented, message: message, title: title, onDismiss: onDismiss))
    }
}
