//
//  Constants.swift
//  YAL
//
//  Created by pankaj nigam on 3/9/26.
//

import SwiftUI

enum UIConstants {
    
    static let pinDigits: Int = 6
    
    // MARK: - Layout & Geometry
    enum Layout {
        /// Standard horizontal padding for screens (20)
        static let screenPadding: CGFloat = 20
        /// Standard padding for internal elements (16)
        static let elementPadding: CGFloat = 16
        /// Small internal padding (12)
        static let internalPadding: CGFloat = 12
        /// Tight spacing for stacked text (2 or 4)
        static let tightSpacing: CGFloat = 4
        /// Standard vertical spacing between form fields (16)
        static let formSpacing: CGFloat = 16
        /// Zero spacing constant
        static let zeroSpacing: CGFloat = 0

        static let paddingSpace: CGFloat = 72
        static let bottomSpace: CGFloat = 100
        static let ExtrainternalPadding: CGFloat = 25

        static let verticalScreenPadding: CGFloat = 40
        static let scaleEffectSpacing: CGFloat = 1.2
        static let verticalPadding: CGFloat = 10
        static let wideScreenPadding: CGFloat = 40
        static let sectionBottomPadding: CGFloat = 30
        static let smallBottomPadding: CGFloat = 15
        static let profileTopPadding: CGFloat = 40
        static let profileToActionPadding: CGFloat = 40
        static let actionButtonSpacing: CGFloat = 20
        static let menuOptionHPadding: CGFloat = 18
        static let menuOptionVPadding: CGFloat = 16
        static let menuItemIconSpacing: CGFloat = 14
        static let deleteButtonHeight: CGFloat = 52
        static let deleteButtonBorderWidth: CGFloat = 1
        static let profileVSpacing: CGFloat = 16
        static let menuIconWidth: CGFloat = 24
        static let menuIconHSpacing: CGFloat = 14
        static let innerTopSpacing: CGFloat = 7
        static let innerMidSpacing: CGFloat = 3
        static let innerBottomSpacing: CGFloat = 5
        static let horizontalPadding: CGFloat = 32
        static let floatingButtonX: CGFloat = 22
        static let floatingButtonY: CGFloat = 55
        static let spacing120: CGFloat = 120
        static let backButtonPadding: CGFloat = 50
        
        static let color1 =  0.4
        static let color2 =  0.5
        static let color3 =  0.9
        static let color4 =  0.12

        static let topPaddinglagging = -40

        enum ActionButton {
            static let width: CGFloat = 56
            static let height: CGFloat = 60
        }

        enum Radius {
            static let small: CGFloat = 8
            static let medium: CGFloat = 12
            static let large: CGFloat = 24
            static let button: CGFloat = 16
        }

        enum Height {
            static let button: CGFloat = 40
            static let inputField: CGFloat = 41
            static let iconSmallest: CGFloat = 14
            static let iconSmall: CGFloat = 16
            static let iconMedium: CGFloat = 40
            static let tapTarget: CGFloat = 44
            static let profileSize: CGFloat = 140
            static let iconAction: CGFloat = 20
            static let chatRowHeight: CGFloat = 48
        }
        // MARK: - Contacts Screen
        enum ContactsScreen {
            static let searchBarHPadding: CGFloat = 20
            static let searchBarTopPadding: CGFloat = 12
            static let searchBarBottomSpacing: CGFloat = 20
            static let bannerHPadding: CGFloat = 16
            static let bannerVPadding: CGFloat = 12
        }

        // MARK: - Invite Banner
        enum InviteBanner {
            static let iconSize: CGFloat = 40
            static let iconBackgroundOpacity: Double = 0.15
            static let hSpacing: CGFloat = 12
            static let titleSubtitleSpacing: CGFloat = 2
            static let horizontalPadding: CGFloat = 16
            static let verticalPadding: CGFloat = 12
            static let cornerRadius: CGFloat = 12
            static let chevronOpacity: Double = 0.8
            static let subtitleOpacity: Double = 0.8
        }
        // MARK: - Edit Profile Sheet
        enum EditProfile {
            enum DragHandle {
                static let width: CGFloat = 60
                static let height: CGFloat = 4
                static let topPadding: CGFloat = 12
            }
            enum Field {
                static let width: CGFloat = 335
                static let height: CGFloat = 41
                static let horizontalPadding: CGFloat = 12
                static let labelSpacing: CGFloat = 8
            }
            enum Button {
                static let width: CGFloat = 150
                static let height: CGFloat = 40
                static let horizontalGap: CGFloat = 35
                static let cornerRadius: CGFloat = 12
                static let borderWidth: CGFloat = 1
            }
            enum Spacing {
                static let headerTopPadding: CGFloat = 16
                static let belowHeader: CGFloat = 24
                static let sectionGap: CGFloat = 16
                static let sheetBottomPadding: CGFloat = 170
                static let headerHPadding: CGFloat = 20
            }
            enum CloseIcon {
                static let size: CGFloat = 16
            }
            static let backgroundColor = "#1A2A35"
            static let genderBackgroundColor = "#0D1A23"
            static let callLogForegroundColor = "#AEAEAE"
            static let selectContactBgColor = "#202D35"

        }
        // MARK: - Profile View
        enum ProfileView {
            static let topBackgroundHeight: CGFloat = 226
            static let scrollContentSpacing: CGFloat = 20
            static let sectionHPadding: CGFloat = 20
            static let aboutTopPadding: CGFloat = 30
            static let fieldGroupSpacing: CGFloat = 20
            static let backButtonTopOffset: CGFloat = 10
            static let backButtonLeading: CGFloat = 20
            static let backButtonVPadding: CGFloat = 10
            static let backButtonSpacing: CGFloat = 10

            enum ProfileImage {
                static let size: CGFloat = 142
                static let topPadding: CGFloat = 80
                static let shadowRadius: CGFloat = 6
            }
            enum CameraButton {
                static let size: CGFloat = 32
                static let strokeWidth: CGFloat = 2
                static let shadowRadius: CGFloat = 4
                static let offset: CGFloat = 6         // x and y offset applied as negative
            }
            enum EditButton {
                static let width: CGFloat = 170
                static let height: CGFloat = 15        // inner text frame height
                static let cornerRadius: CGFloat = 12
                static let shadowRadius: CGFloat = 2
                static let topPadding: CGFloat = 80
                static let bottomPadding: CGFloat = 40
                static let hPadding: CGFloat = 20
            }
            enum ProfileField {
                static let hSpacing: CGFloat = 16      // HStack spacing between icon and text
                static let textSpacing: CGFloat = 4    // VStack spacing between value and title
                static let iconSize: CGFloat = 18
                static let emptyOpacity: Double = 0.3
            }
            enum AboutSection {
                static let textSpacing: CGFloat = 8    // VStack spacing
                static let hPadding: CGFloat = 12
                static let labelOpacity: Double = 0.6
                static let editorHeight: CGFloat = 200
                static let editorOpacity: Double = 0.7
                static let cornerRadius: CGFloat = 8
            }
            enum BackButton {
                static let iconSize: CGFloat = 16
                static let hSpacing: CGFloat = 10
            }
            static let iconOpacity: Double = 0.6
            static let subtitleOpacity: Double = 0.8
            
            static let profileTopBackground   = SwiftUI.Color(hex: "#0A171F")
            static let profileBodyBackground  = SwiftUI.Color(hex: "#202D35").opacity(0.8)
        }
    }
    
    // MARK: - Opacity & Alpha
    enum Opacity {
        static let highest: Double = 1.0
        static let high: Double = 0.8
        static let medium: Double = 0.6
        static let overlay: Double = 0.3
        static let low: Double = 0.15
        static let veryLow: Double = 0.1
        static let lowest: Double = 0.001
    }
    
    // MARK: - Universal Symbols (SF Symbols)
    enum Symbols {
        static let chevronRight = "chevron.right"
        static let chevronDown = "chevron.down"
        static let chevronUp = "chevron.up"
        static let calendar = "calendar"
        static let close = "xmark"
        static let tickCircleGreen = "tick-circle-green"
        static let backIcon = "back-long"
        static let callAdd = "call-add"
        static let checkBoxCircle = "circle"
        static let checkBoxCircleFilled = "circle.inset.filled"
        static let arrowRightWhite = "arrow-right-white"
        static let arrowDownCircleFilled = "arrow.down.circle.fill"
        static let crossBlack = "cross-black"
        static let lockBlack = "lockBlack"
        static let checkMark = "Check Mark"
        static let addWhite = "add-white"
        static let lockWhite = "lockWhite"
        static let objects = "objects"
        static let animal_ss = "animal_ss"
    }
    // MARK: - Navigation Bar
    enum NavBar {
        static let horizontalPadding: CGFloat = 4
        static let topPadding: CGFloat = 64
        static let bottomPadding: CGFloat = 8
        static let zeroSpacing: CGFloat = 0

    }
}

// MARK: - Chat Layout (top-level, accessible everywhere)
enum ChatLayout {
    static let receiverTrailingPadRatio: CGFloat  = 0.30
    static let senderLeadingPad: CGFloat          = 20
    static let inputBarBottomPad: CGFloat         = 0
    static let attachmentThumbnailSize: CGFloat   = 68
    static let attachmentSpacing: CGFloat         = 12
    static let topBarHorizontalPad: CGFloat       = 8
    static let topBarVerticalPad: CGFloat         = 4
    static let searchBarHeight: CGFloat           = 44
    static let searchBarCornerRadius: CGFloat     = 12
    static let searchIconSize: CGFloat            = 20
    static let searchCounterWidth: CGFloat        = 80
    static let searchCounterHeight: CGFloat       = 26
    static let searchCounterCornerRadius: CGFloat = 10
    static let scrollBarWidth: CGFloat            = 4
    static let scrollBarMinThumbHeight: CGFloat   = 32
    static let contextMenuSpacerHeight: CGFloat   = 250
    static let groupPopupAvatarSize: CGFloat      = 56
    static let groupPopupWidth: CGFloat           = 260
    static let groupPopupHeight: CGFloat          = 230
    static let groupPopupButtonWidth: CGFloat     = 220
    static let groupPopupButtonHeight: CGFloat    = 40
    static let groupPopupAddButtonHeight: CGFloat = 44
    static let groupPopupCornerRadius: CGFloat    = 8
    static let groupPopupTopSpacer: CGFloat       = 70
    static let mediaPickerSpacing: CGFloat        = 30
    static let mediaPickerButtonSize: CGFloat     = 60
    static let mediaPickerCornerRadius: CGFloat   = 24
    static let mediaOverlayBottomPad: CGFloat     = 90
    static let mediaOverlayHorizontalPad: CGFloat = 16
    static let messageSectionSpacing: CGFloat     = 20
    static let messageBottomPad: CGFloat          = 8
    static let suggestionGifHeight: CGFloat       = 95
    static let suggestionGifOffsetY: CGFloat      = -50
    static let notAMemberHPad: CGFloat            = 60
    static let scrollToBottomTrailingPad: CGFloat = 16
    static let scrollToBottomBottomPad: CGFloat   = 8
    static let viewTopPad: CGFloat                = 56
    static let resultCounts: CGFloat              = 5
    static let frmaeHeightWidth: CGFloat          = 24
    static let zIndexValue: CGFloat                = 1
    static let replyViewHeight: CGFloat           = 66
    static let replyViewWidth: CGFloat            = 355
}


// MARK: - Blocked User Screen
enum BlockedUserScreen {
    static let avatarSize: CGFloat = 48
    static let avatarFallbackSize: CGFloat = 56
    static let avatarStrokeWidth: CGFloat = 2
    static let avatarInitialsFontSize: CGFloat = 20
    static let rowHPadding: CGFloat = 20
    static let rowVPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let removeButtonHPadding: CGFloat = 16
    static let removeButtonVPadding: CGFloat = 8
    static let listTopPadding: CGFloat = 20
    static let listBottomPadding: CGFloat = 20
    static let backIconSize: CGFloat = 20
    static let backIconHPadding: CGFloat = 10
    static let backIconVPadding: CGFloat = 10
    static let navTopPadding: CGFloat = 60
    static let emptyStateTopPaddingOffset: CGFloat = 120
}
