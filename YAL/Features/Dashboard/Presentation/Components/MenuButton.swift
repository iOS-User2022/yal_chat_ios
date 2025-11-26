//
//  MenuButton.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/04/25.
//

import SwiftUI

struct MenuButton: View {
    var onTap: () -> Void = {}

    var body: some View {
        Image("menu")
            .resizable()
            .frame(width: 24, height: 24)
            .onTapGesture(perform: onTap)
    }
}
