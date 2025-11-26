//
//  View+MatchedGeometryIf.swift
//  YAL
//
//  Created by Vishal Bhadade on 05/11/25.
//

import SwiftUI

public extension View {
    @ViewBuilder
    func matchedGeometryIf(
        _ condition: Bool,
        id: AnyHashable,
        in namespace: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        if condition {
            self.matchedGeometryEffect(
                id: id,
                in: namespace,
                properties: properties,
                anchor: anchor,
                isSource: isSource
            )
        } else {
            self
        }
    }
}
