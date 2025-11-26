//
//  CustomRoundedCornersShape.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//


import SwiftUI

// Enum to define which corners to round
enum RoundedCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct CustomRoundedCornersShape: Shape {
    var radius: CGFloat
    var roundedCorners: [RoundedCorner]
    
    func path(in rect: CGRect) -> Path {
        var path = UIBezierPath()

        var cornersToRound: UIRectCorner = []
        
        // Add corners based on the array
        if roundedCorners.contains(.topLeft) {
            cornersToRound.insert(.topLeft)
        }
        if roundedCorners.contains(.topRight) {
            cornersToRound.insert(.topRight)
        }
        if roundedCorners.contains(.bottomLeft) {
            cornersToRound.insert(.bottomLeft)
        }
        if roundedCorners.contains(.bottomRight) {
            cornersToRound.insert(.bottomRight)
        }
        
        // Create the rounded rectangle with the selected corners
        path = UIBezierPath(roundedRect: rect,
                            byRoundingCorners: cornersToRound,
                            cornerRadii: CGSize(width: radius, height: radius))

        // Determine the pointed corner by finding the corners that were not rounded
        let allCorners: [RoundedCorner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        let pointedCorner = allCorners.first { !roundedCorners.contains($0) }
        
        // Draw the pointed corner by cutting off the non-rounded corner
        switch pointedCorner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y))
            path.addLine(to: CGPoint(x: rect.origin.x + rect.width * 0.2, y: rect.origin.y))
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.origin.y))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.origin.y))
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.origin.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.origin.x + rect.width * 0.2, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.maxY))
        case .none:
            break // In case all corners are rounded, no pointed corner.
        }

        return Path(path.cgPath)
    }
}
