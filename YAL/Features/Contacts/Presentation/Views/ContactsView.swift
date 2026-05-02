//
//  ContactsView.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI

private enum ContactsTypography {
    static let bannerTitle = Design.TextStyle.bannerTitle
    static let bannerSubtitle = Design.TextStyle.bannerSubtitle
    static let bannerChevron = Design.TextStyle.bannerChevron
}

struct ContactsView: View {
    @StateObject private var viewModel: ContactListViewModel
    @State private var selectedFilter: ContactFilter = .all
    @State private var searchText: String = ""
    @State private var showAlert: Bool = false
    @State private var navPath = NavigationPath()

    init() {
        let viewModel = DIContainer.shared.container.resolve(ContactListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                contentView
                .background(Design.Color.backgroundColor)
                .onAppear {
                    viewModel.startContactSync()
                }
                .onChange(of: viewModel.accessStatus) { status in
                    handleAccessStatusChange(status)
                }
                .onReceive(viewModel.$sections) { sections in
                    #if DEBUG
                    let contacts = sections.flatMap { $0.contacts }
                    let sample = contacts.prefix(20).map { contact in
                        let name = contact.fullName ?? contact.displayName ?? "Unknown"
                        let userId = contact.userId ?? "nil"
                        return "\(name) | \(contact.phoneNumber) | userId: \(userId)"
                    }.joined(separator: "\n")

                    print("[ContactsView] Final sections: \(sections.count), contacts: \(contacts.count)")
                    if !sample.isEmpty {
                        print("[ContactsView] Final contacts sample:\n\(sample)")
                    }
                    #endif
                }
                
                if showAlert, let alertModel = viewModel.alertModel {
                    AlertView(model: alertModel) {
                        showAlert = false
                    }
                }
            }
            .navigationDestination(for: ContactNavigation.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: UIConstants.NavBar.zeroSpacing) {
            searchSection
            TabFiltersView(filters: [ContactFilter.all], selectedFilter: $selectedFilter)
            accessStateContent
            inviteBannerSection
        }
    }

    private var searchSection: some View {
        VStack(spacing: UIConstants.NavBar.zeroSpacing) {
            SearchBarView(placeholder: Constants.searchPlaceholderText.localized, text: $searchText)
                .padding(.horizontal, UIConstants.Layout.ContactsScreen.searchBarHPadding)
                .padding(.top, UIConstants.Layout.ContactsScreen.searchBarTopPadding)

            Spacer().frame(height: UIConstants.Layout.ContactsScreen.searchBarBottomSpacing)
        }
    }

    @ViewBuilder
    private var accessStateContent: some View {
        switch viewModel.accessStatus {
        case .unknown:
            centeredMessage { ProgressView() }
        case .granted:
            ContactSectionedList(
                sections: viewModel.filteredSections(for: searchText),
                navPath: $navPath
            )
            .background(Design.Color.backgroundColor)
        case .denied:
            centeredMessage {
                Text(Constants.contactPermissionDenied.localized)
                    .foregroundColor(.secondary)
            }
        case .restricted:
            centeredMessage {
                Text(Constants.contactAccessRestricted.localized)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var inviteBannerSection: some View {
        InviteFriendsBannerView()
            .padding(.horizontal, UIConstants.Layout.ContactsScreen.bannerHPadding)
            .padding(.vertical, UIConstants.Layout.ContactsScreen.bannerVPadding)
            .padding(.bottom, UIConstants.Layout.internalPadding)
    }

    @ViewBuilder
    private func centeredMessage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: ContactNavigation) -> some View {
        switch destination {
        case .contactInfo(let contact):
            ContactInfoView(
                name: contact.name,
                phoneNumber: contact.phoneNumber,
                email: contact.email,
                avatarUrl: contact.avatarUrl
            )
        }
    }

    private func handleAccessStatusChange(_ status: ContactAccessStatus) {
        switch status {
        case .denied:
            viewModel.showAlertForDeniedPermission()
            showAlert = true
        case .restricted:
            viewModel.showAlertForRestrictedAccess()
            showAlert = true
        default:
            break
        }
    }
}

// MARK: - Invite Friends Banner

struct InviteFriendsBannerView: View {
    var body: some View {
        Button(action: {}) {
            HStack(spacing: UIConstants.Layout.InviteBanner.hSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(UIConstants.Layout.InviteBanner.iconBackgroundOpacity))
                        .frame(
                            width:  UIConstants.Layout.InviteBanner.iconSize,
                            height: UIConstants.Layout.InviteBanner.iconSize
                        )
                    Image(.friend)
                        .frame(
                            width:  UIConstants.Layout.InviteBanner.iconSize,
                            height: UIConstants.Layout.InviteBanner.iconSize
                        )
                }

                VStack(alignment: .leading,
                       spacing: UIConstants.Layout.InviteBanner.titleSubtitleSpacing) {
                    Text(Constants.inviteFriends.localized)
                        .font(ContactsTypography.bannerTitle)
                        .foregroundColor(.white)
                    Text(Constants.contactOnYal.localized)
                        .font(ContactsTypography.bannerSubtitle)
                        .foregroundColor(.white.opacity(UIConstants.Layout.InviteBanner.subtitleOpacity))
                }

                Spacer()

                Image(systemName: UIConstants.Symbols.chevronRight)
                    .font(ContactsTypography.bannerChevron)
                    .foregroundColor(.white.opacity(UIConstants.Layout.InviteBanner.chevronOpacity))
            }
            .padding(.horizontal, UIConstants.Layout.InviteBanner.horizontalPadding)
            .padding(.vertical,   UIConstants.Layout.InviteBanner.verticalPadding)
            .background(Design.Color.appGradient)
            .cornerRadius(UIConstants.Layout.InviteBanner.cornerRadius)
        }
    }
}



// MARK: - Navigation

enum ContactNavigation: Hashable {
    case contactInfo(contact: ContactDisplayData)
}

struct ContactDisplayData: Hashable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    /// Primary email from profile enrichment; empty when unknown.
    let email: String
    let avatarUrl: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContactDisplayData, rhs: ContactDisplayData) -> Bool {
        lhs.id == rhs.id
    }
}
