//
//  Design.swift
//  YAL
//
//  Created by Vishal Bhadade on 15/04/25.
//


import SwiftUI

struct Design {
    enum FontFamily {
        case sfPro
    }

    struct Typography {
        struct Family {
            fileprivate let kind: FontFamily

            func ultraLight(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .ultraLight)
            }

            func thin(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .thin)
            }

            func light(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .light)
            }

            func regular(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .regular)
            }

            func medium(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .medium)
            }

            func semiBold(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .semibold)
            }

            func bold(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .bold)
            }

            func heavy(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .heavy)
            }

            func black(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .black)
            }

            func italic(_ size: CGFloat) -> SwiftUI.Font {
                make(size: size, weight: .regular).italic()
            }

            private func make(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
                switch kind {
                case .sfPro:
                    // iOS system default design maps to SF Pro.
                    return .system(size: size, weight: weight, design: .default)
                }
            }
        }

        static let sfPro = Family(kind: .sfPro)
    }

    struct Font {
        // Backward-compatible aliases (defaults to SF Pro family).
        static func ultraLight(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.ultraLight(size)
        }
        
        static func thin(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.thin(size)
        }
        
        static func light(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.light(size)
        }
        
        static func regular(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.regular(size)
        }
        
        static func medium(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.medium(size)
        }
        
        static func semiBold(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.semiBold(size)
        }
        
        static func bold(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.bold(size)
        }
        
        static func heavy(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.heavy(size)
        }
        
        static func black(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.black(size)
        }
        
        static func italic(_ size: CGFloat) -> SwiftUI.Font {
            Typography.sfPro.italic(size)
        }
        
        // MARK: - Common Font Styles
        static let title = bold(24)
        static let subtitle = semiBold(18)
        static let body = regular(16)
        static let caption = regular(12)
        static let button = medium(16)
        
        // MARK: - Blocked User Screen
        static let blockedNavTitle     = Font.semiBold(16)
        static let blockedUserName     = Font.semiBold(16)
        static let blockedUserPhone    = Font.regular(14)
        static let blockedRemoveButton = Font.semiBold(14)
        static let blockedEmptyState   = Font.regular(16)
        static let blockedInitials     = Font.semiBold(20)
    }
    
    struct Color {
        // MARK: - Figma Design Colors
        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let green = SwiftUI.Color.green
        static let clear = SwiftUI.Color.clear
        
        static let backgroundColor = SwiftUI.Color(red: 0.039, green: 0.090, blue: 0.122) // #0A171F
        static let primaryTextColor = SwiftUI.Color(red: 0.969, green: 0.969,blue: 0.969) // #F7F7F7
        static let secondryTextColor = SwiftUI.Color(red: 179/255, green: 179/255, blue: 179/255) // #B3B3B3
        static let blueHedlineColor = SwiftUI.Color(red: 12/255, green: 123/255, blue: 255/255) //#0C7BFF
        static let darkgrayColor = SwiftUI.UIColor(red: 32/255,green: 45/255,blue: 53/255,alpha: 1) //#202D35

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
        static let errorRed = SwiftUI.Color(red: 1.0, green: 0.11, blue: 0.27) // #FF1D45
        
        static let purple = SwiftUI.Color(red: 0.55, green: 0.32, blue: 0.95)
        static let lightBlue = SwiftUI.Color(red: 0.27, green: 0.45, blue: 1.0)

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
        
        static let  medium_gray = SwiftUI.Color(red: 150/255, green: 150/255, blue: 150/255) // #969696

        // MARK: - Border / Stroke
        static let border = mediumGray
        static let inputBorder = darkGrayText
        
        static let disabledLightBlue = SwiftUI.Color(red: 159/255, green: 181/255, blue: 217/255) // #9FB5D9
        static let disabledPurple   = SwiftUI.Color(red: 169/255, green: 158/255, blue: 204/255) // #A99ECC

        static let disabledGradient = LinearGradient(
            colors: [disabledLightBlue, disabledPurple],
            startPoint: .leading,
            endPoint: .trailing
        )

        // MARK: - Gradients
        static let appGradient = LinearGradient(
            stops: [
                .init(color: lightBlue, location: 0.0),
                .init(color: purple, location: 1.0),
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

        // MARK: - Blocked User Screen
        /// #FF3B5C — red used for the remove/unblock action button
        static let blockedRemoveRed = SwiftUI.Color(red: 1.0, green: 0.231, blue: 0.361) // #FF3B5C
        /// #0A1929 — dark navy background used across the blocked user screen
        static let navBackground = SwiftUI.Color(red: 10/255, green: 25/255, blue: 41/255) // #0A1929
        /// Fallback avatar circle fill
        static let avatarFallbackFill = SwiftUI.Color.gray.opacity(0.3)
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
    struct TextStyle {
        // MARK: - Contact Info
        static let contactNavTitle    = Font.semiBold(16)
        static let contactName        = Font.semiBold(16)
        static let contactPhone       = Font.regular(12)
        static let contactActionLabel = Font.regular(13)
        static let contactMenuItem    = Font.bold(14)
        static let contactDeleteLabel = Font.medium(14)
        // Navigation
        static let navTitle        = Font.semiBold(16)
        
        static let actionLabel     = Font.regular(13)
        static let menuItem        = Font.bold(14)
        static let deleteLabel     = Font.medium(14)
        static let deleteIcon      = Font.regular(14)
        static let initialsLabel   = Font.bold(48)
        static let menuIconSize    = Font.regular(20)
        static let navChevron      = Font.semiBold(20)
        
        // Invite Banner
        static let bannerTitle    = Font.semiBold(14)
        static let bannerSubtitle = Font.regular(12)
        static let bannerChevron  = Font.regular(20)
        
        // MARK: - Edit Profile
        static let editProfileTitle        = Font.bold(14)
        static let editProfileFieldLabel   = Font.regular(12)
        static let editProfileFieldText    = Font.regular(14)
        static let editProfileButton       = Font.semiBold(14)
        static let editProfileCloseIcon    = Font.medium(16)
        static let editProfileChevronIcon  = Font.medium(12)
        static let editProfileCalendarIcon = Font.regular(14)
        
        // MARK: - Profile View
        static let profileNavTitle   = Font.bold(16)
        static let profileNavTitleLg = Font.bold(18)   // used in headerSection()
        static let profileEditButton = Font.semiBold(14)
        static let profileFieldValue = Font.semiBold(14)
        static let profileFieldTitle = Font.medium(12)
        static let profileAboutLabel = Font.medium(12)
        static let profileAboutText  = Font.regular(12)
    }
    // MARK: - Chat Text Styles (top-level, accessible everywhere)
    struct ChatTextStyles {
        static let sectionDateLabel   = Design.Font.regular(12)
        static let senderName         = Design.Font.semiBold(13)
        static let messageBody        = Design.Font.regular(14)
        static let timestamp          = Design.Font.regular(10)
        static let replyPreview       = Design.Font.regular(12)
        static let typingIndicator    = Design.Font.italic(12)
        static let inputPlaceholder   = Design.Font.regular(14)
        static let suggestionChip     = Design.Font.medium(14)
        static let forwardCount       = Design.Font.bold(14)
        static let searchCounter      = Design.Font.medium(12)
        static let notAMemberTitle    = Design.Font.regular(14)
        static let deleteDialogTitle  = SwiftUI.Font.headline
        static let deleteDialogAction = Design.Font.regular(14)
        static let emptyStateHeadline = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let emptyStateSubtitle = SwiftUI.Font.system(size: 14, weight: .regular)
        static let groupPopupTitle    = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let groupMemberCount   = SwiftUI.Font.system(size: 8)
        static let groupStartButton   = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let groupAddButton     = SwiftUI.Font.system(size: 14)
        static let noResultsLabel     = Design.Font.regular(12)
        static let mediaPickerLabel   = SwiftUI.Font.caption
        static let fontSizeText   = Design.Font.medium(22)
        static let typingUser      = Design.Font.medium(12)

    }
}
extension Design {
    struct Icons {
        enum SFSymbol: String {
            case groupFill = "person.3.fill"
            case closeCircle = "xmark.circle.fill"
            case chevronUp   = "chevron.up"
            case chevronDown   = "chevron.down"
        }
        
        static func image(_ symbol: SFSymbol) -> Image {
            Image(systemName: symbol.rawValue)
        }
    }
}
