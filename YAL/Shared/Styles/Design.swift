//
//  Design.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//


import SwiftUI

struct Design {
    struct Font {
        // MARK: - Font Weight Variants
        static func ultraLight(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .ultraLight, design: .default)
        }
        
        static func thin(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .thin, design: .default)
        }
        
        static func light(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .light, design: .default)
        }
        
        static func regular(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .default)
        }
        
        static func medium(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .default)
        }
        
        static func semiBold(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        
        static func bold(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .default)
        }
        
        static func heavy(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .heavy, design: .default)
        }
        
        static func black(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .black, design: .default)
        }
        
        static func italic(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .thin, design: .default).italic()
        }
        
        // MARK: - Common Font Styles
        static let title = bold(24)
        static let subtitle = semiBold(18)
        static let body = regular(16)
        static let caption = regular(12)
        static let button = medium(16)
    }
    
    struct Color {
        // MARK: - Figma Design Colors
        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let green = SwiftUI.Color.green
        static let clear = SwiftUI.Color.clear
        
        static let headingText = SwiftUI.Color(red: 0.13, green: 0.12, blue: 0.17) // #211E2B
        static let grayText = SwiftUI.Color(red: 0.48, green: 0.48, blue: 0.48)    // #7A7A7A
        static let darkGrayText = SwiftUI.Color(red: 0.23, green: 0.23, blue: 0.23) // #3A3A3A
        static let mediumGray = SwiftUI.Color(red: 0.76, green: 0.76, blue: 0.76)   // #C2C2C2 approx
        static let translucentBlue = SwiftUI.Color(red: 0.07, green: 0.16, blue: 0.49)
        static let error = SwiftUI.Color(red: 0.78, green: 0, blue: 0) // error red
        static let navy = SwiftUI.Color(red: 0, green: 0, blue: 0.16) // deep navy blue
        static let blue = SwiftUI.Color(red: 0, green: 0.38, blue: 0.61)
        static let purpleAccent = SwiftUI.Color(red: 0.37, green: 0.24, blue: 0.72)
        static let darkText = SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.1)
        static let mutedText = SwiftUI.Color(red: 0.6, green: 0.6, blue: 0.6)
        static let successGreen = SwiftUI.Color(red: 0.12, green: 0.75, blue: 0.0)
        static let tertiaryText = SwiftUI.Color(red: 0.51, green: 0.51, blue: 0.53)
        static let destructiveRed = SwiftUI.Color(red: 0.96, green: 0.34, blue: 0.34)
        static let deepGreen = SwiftUI.Color(red: 0, green: 0.45, blue: 0.16)
        static let headingDark = SwiftUI.Color(red: 0.0039, green: 0.0, blue: 0.1608) // #010029

        // MARK: - Primary Text Colors
        static let primaryText = headingText
        static let secondaryText = grayText
        
        // MARK: - Backgrounds
        static let lighterGrayBackground = SwiftUI.Color(red: 0.93, green: 0.93, blue: 0.93)
        static let lightGrayBackground = SwiftUI.Color(red: 0.94, green: 0.94, blue: 0.94) // #F0F0F0
        static let lightBackground = SwiftUI.Color(red: 0.89, green: 0.91, blue: 0.97)
        static let background = lightGrayBackground
        static let cardBackground = SwiftUI.Color("CardBackground") // placeholder
        static let chatBackground = SwiftUI.Color.white
        static let backgroundMuted = SwiftUI.Color(red: 0.82, green: 0.85, blue: 0.93)
        static let receiverTime = SwiftUI.Color(red: 0.68, green: 0.68, blue: 0.68)
        static let senderTime = SwiftUI.Color(red: 0.94, green: 0.94, blue: 0.97)

        static let lightWhiteBackground = SwiftUI.Color(red: 0.94, green: 0.94, blue: 0.94)
        static let dangerBackground = SwiftUI.Color(red: 0.79, green: 0.16, blue: 0.17)

        // MARK: - Border / Stroke
        static let border = mediumGray
        static let inputBorder = darkGrayText
        
        // MARK: - Gradients
        static let appGradient = LinearGradient(
            stops: [
                .init(color: navy, location: 0.0),
                .init(color: blue, location: 1.0),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        
        static let loadingBackground = LinearGradient(
            gradient: Gradient(colors: [
                white,
                lightBackground
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let tabHighlight = LinearGradient(
            stops: [
                .init(color: SwiftUI.Color(red: 0, green: 0, blue: 0.16), location: 0.0),
                .init(color: SwiftUI.Color(red: 0, green: 0.38, blue: 0.61), location: 1.0)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
        
        static var greenGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: SwiftUI.Color(red: 0.12, green: 0.71, blue: 0.2), location: 0.00),
                    .init(color: SwiftUI.Color(red: 0.34, green: 0.98, blue: 0.43), location: 1.00),
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        
        static var blueGradient: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: SwiftUI.Color(red: 0.82, green: 0.85, blue: 0.93), location: 0.00),
                    .init(color: SwiftUI.Color(red: 0.86, green: 0.92, blue: 0.97), location: 1.00),
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
    }
}

extension Design {
    struct Background {
        static var radialGlow: some View {
            GeometryReader { geo in
                let size = max(geo.size.width, geo.size.height) * 1.8
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                SwiftUI.Color(hex: "#001F9D"),
                                SwiftUI.Color(hex: "#DBE2FF")
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size / 2
                        )
                    )
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.3)
                    .opacity(0.56)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}
