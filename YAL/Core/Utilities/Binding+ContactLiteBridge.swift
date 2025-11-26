//
//  Binding+ContactLiteBridge.swift
//  YAL
//
//  Created by Vishal Bhadade on 16/11/25.
//

import SwiftUI

extension Binding where Value == [ContactModel] {
    /// Two-way bridge: [ContactModel] ⟷ [ContactLite]
    func asLite() -> Binding<[ContactLite]> {
        Binding<[ContactLite]>(
            get: { self.wrappedValue.map { $0.toLite() } },
            set: { newLite in
                self.wrappedValue = newLite.map { ContactModel.fromLite($0) }
            }
        )
    }
}
