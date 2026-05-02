//
//  contact.swift
//  YAL
//
//  Created by Hari krishna on 23/01/26.
//

import SwiftUI

private enum ContactInfoTypography {
    static let navChevron = Design.TextStyle.navChevron
    static let navTitle = Design.TextStyle.navTitle
    static let contactName = Design.TextStyle.contactName
    static let contactPhone = Design.TextStyle.contactPhone
    static let deleteIcon = Design.TextStyle.deleteIcon
    static let deleteLabel = Design.TextStyle.deleteLabel
    static let initialsLabel = Design.TextStyle.initialsLabel
    static let actionLabel = Design.TextStyle.contactActionLabel
    static let menuIcon = Design.TextStyle.menuIconSize
    static let menuItem = Design.TextStyle.menuItem
}

private enum ContactInfoL10n {
    static let title = NSLocalizedString("CONTACT_INFO_TITLE", comment: "")
    static let actionChat = NSLocalizedString("CONTACT_INFO_ACTION_CHAT", comment: "")
    static let actionCall = NSLocalizedString("CONTACT_INFO_ACTION_CALL", comment: "")
    static let actionVideo = NSLocalizedString("CONTACT_INFO_ACTION_VIDEO", comment: "")
    static let menuAddToFavorites = NSLocalizedString("CONTACT_INFO_MENU_ADD_TO_FAVORITES", comment: "")
    static let menuReportSpam = NSLocalizedString("CONTACT_INFO_MENU_REPORT_SPAM", comment: "")
    static let menuBlock = NSLocalizedString("CONTACT_INFO_MENU_BLOCK", comment: "")
    static let deleteContact = NSLocalizedString("CONTACT_INFO_DELETE_CONTACT", comment: "")
}

enum ContactActionType {
    case chat
    case call
    case video

    var assetImage: ImageResource {
        switch self {
        case .chat:
            return .chatsSelected
        case .call:
            return .call
        case .video:
            return .video
        }
    }
}

struct ContactInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    let name: String
    let phoneNumber: String
    let email: String
    let avatarUrl: String?
    
    var body: some View {
        ZStack(alignment: .top) {
            Design.Color.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: UIConstants.NavBar.zeroSpacing) {
                headerView
                
                ScrollView {
                    VStack(spacing:UIConstants.NavBar.zeroSpacing) {
                        profileSection
                        actionButtonsSection
                        menuSection
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            deleteContactSection
                .padding(.top, UIConstants.Layout.sectionBottomPadding)
                .background(Design.Color.backgroundColor)
        }
        .navigationBarHidden(true)
        .onAppear {
            #if DEBUG
            print("[ContactInfoView] Contact detail — name: \(name), phone: \(phoneNumber), email: \(email), avatar: \(avatarUrl ?? "nil")")
            #endif
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(.chevronLeft)
                    .font(ContactInfoTypography.navChevron)
                    .foregroundColor(.white)
                    .frame(width: UIConstants.Layout.Height.tapTarget, height: UIConstants.Layout.Height.tapTarget)
            }

            Text(ContactInfoL10n.title)
                .font(ContactInfoTypography.navTitle)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, UIConstants.NavBar.horizontalPadding)
        .padding(.top, UIConstants.NavBar.topPadding)
        .padding(.bottom, UIConstants.NavBar.bottomPadding)
    }

    private var profileSection: some View {
        VStack(spacing: UIConstants.Layout.profileVSpacing) {
            avatarView

            Text(name)
                .font(ContactInfoTypography.contactName)
                .foregroundColor(.white)

            Text(phoneNumber)
                .font(ContactInfoTypography.contactPhone)
                .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
            if !email.isEmpty {
                Text(email)
                    .font(ContactInfoTypography.contactPhone)
                    .foregroundColor(.white.opacity(UIConstants.Opacity.medium))
            }
        }
        .padding(.top, UIConstants.Layout.verticalScreenPadding)
        .padding(.bottom, UIConstants.Layout.verticalScreenPadding)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl, !avatarUrl.isEmpty {
            NonInteractiveMediaView(
                mediaURL: avatarUrl,
                userName: name,
                timeText: "",
                mediaType: .image,
                placeholder: placeholderView,
                errorView: placeholderView,
                isSender: false,
                downloadedImage: nil,
                senderImage: "",
                localURLOverride: nil
            )
            .frame(width: UIConstants.Layout.Height.profileSize, height: UIConstants.Layout.Height.profileSize)
            .clipShape(Circle())
        } else {
            placeholderView
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: UIConstants.Layout.actionButtonSpacing) {
            ActionButton(title: ContactInfoL10n.actionChat, actionType: .chat) {}

            ActionButton(title: ContactInfoL10n.actionCall, actionType: .call) {
                callContact()
            }

            ActionButton(title: ContactInfoL10n.actionVideo, actionType: .video) {}
        }
        .padding(.horizontal, UIConstants.Layout.wideScreenPadding)
        .padding(.bottom, UIConstants.Layout.verticalScreenPadding)
    }

    private var menuSection: some View {
        VStack(spacing: UIConstants.NavBar.zeroSpacing) {
            MenuOption(
                icon: "star",
                title: ContactInfoL10n.menuAddToFavorites,
                iconColor: .white,
                textColor: .white
            ) {}

            MenuOption(
                icon: "message-question",
                title: ContactInfoL10n.menuReportSpam,
                iconColor: .white,
                textColor: .white
            ) {}

            MenuOption(
                icon: "shield-cross1",
                title: ContactInfoL10n.menuBlock,
                iconColor: Design.Color.errorRed,
                textColor: Design.Color.errorRed
            ) {}
        }
        .cornerRadius(UIConstants.Layout.Radius.medium)
        .padding(.horizontal, UIConstants.Layout.screenPadding)
        .padding(.bottom, UIConstants.Layout.sectionBottomPadding)
    }

    private var deleteContactSection: some View {
        Button(action: {}) {
            HStack(spacing: UIConstants.Layout.actionButtonSpacing) {
                Image(.trash)
                    .font(ContactInfoTypography.deleteIcon)
                Text(ContactInfoL10n.deleteContact)
                    .font(ContactInfoTypography.deleteLabel)
            }
            .foregroundColor(Design.Color.errorRed)
            .frame(maxWidth: .infinity)
            .frame(height: UIConstants.Layout.deleteButtonHeight)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.medium)
                    .stroke(
                        Design.Color.errorRed,
                        lineWidth: UIConstants.Layout.deleteButtonBorderWidth
                    )
            )
        }
        .padding(.horizontal, UIConstants.Layout.screenPadding)
        .padding(.bottom, UIConstants.Layout.verticalScreenPadding)
    }

    private func callContact() {
        let numericPhone = phoneNumber.filter { $0.isNumber }
        guard let url = URL(string: "tel://\(numericPhone)") else { return }
        UIApplication.shared.open(url)
    }
    
    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(randomBackgroundColor())
                .frame(width: UIConstants.Layout.Height.profileSize, height: UIConstants.Layout.Height.profileSize)
            
            Text(getInitials(from: name))
                .font(ContactInfoTypography.initialsLabel)
                .foregroundColor(.white.opacity(UIConstants.Opacity.high))
        }
    }
}

struct ActionButton: View {
    let title: String
    let actionType: ContactActionType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            
            ZStack {
                
                RoundedRectangle(cornerRadius: UIConstants.Layout.Radius.button)
                    .fill(Color(Design.Color.darkgrayColor))
                    .frame(width: UIConstants.Layout.ActionButton.width, height: UIConstants.Layout.ActionButton.height)
                VStack {
                    Spacer(minLength: UIConstants.Layout.innerTopSpacing)
                    Image(actionType.assetImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: UIConstants.Layout.Height.iconAction, height: UIConstants.Layout.Height.iconAction)
                    Spacer(minLength: UIConstants.Layout.innerMidSpacing)
                    Text(title)
                        .font(ContactInfoTypography.actionLabel)
                        .foregroundColor(.white.opacity(UIConstants.Opacity.high))
                    Spacer(minLength: UIConstants.Layout.innerBottomSpacing)
                    
                }
            }
        }
        
    }
}
struct MenuOption: View {
    let icon: String
    let title: String
    let iconColor: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: UIConstants.Layout.menuIconHSpacing) {
                Image(icon)
                    .font(ContactInfoTypography.menuIcon)
                    .foregroundColor(iconColor)
                    .frame(width: UIConstants.Layout.menuIconWidth)
                
                Text(title)
                    .font(ContactInfoTypography.menuItem)
                    .foregroundColor(textColor)
                
                Spacer()
            }
            .padding(.horizontal, UIConstants.Layout.menuOptionHPadding)
            .padding(.vertical,   UIConstants.Layout.menuOptionVPadding)
            .contentShape(Rectangle())
        }
    }
}

