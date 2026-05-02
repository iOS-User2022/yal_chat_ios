//
//  ContactsListView.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//


import SwiftUI

enum GroupCreateRoute: Hashable, Decodable {
    case groupSelect
    case groupName // Pass selected contacts
}

struct SelectContactsListView: View {
    @EnvironmentObject var router: Router
    @StateObject private var viewModel: SelectContactListViewModel
    @Binding var participants: [ContactLite]
    @Binding var invitedContacts: [ContactLite]
    @State private var showGroupSelector = false
    @State private var navPath = NavigationPath()
    
    var onDismiss: (() -> Void)?
    var onComplete: ((String?, String?) -> Void)?
    
    init(participants: Binding<[ContactLite]>, invitedContacts: Binding<[ContactLite]>, onComplete: ((String?, String?) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        let viewModel = DIContainer.shared.container.resolve(SelectContactListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        _participants = participants
        _invitedContacts = invitedContacts
        self.onDismiss = onDismiss
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                // Header Section with back button, title, and more button
                headerView()

                // Search Bar Section
                searchBarView()

                // Content Section (buttons and list)
                contentSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Design.Color.backgroundColor)
            .onAppear {
                viewModel.startContactSync()
            }
            .navigationDestination(for: GroupCreateRoute.self) { route in
                switch route {
                case .groupSelect:
                    NewGroupContactSelectorView(viewModel: viewModel, selectedContacts: $participants, invitedContacts: $invitedContacts) {
                        navPath.append(GroupCreateRoute.groupName)
                    } onDismiss: {
                        onDismiss?()
                    }
                    .navigationBarBackButtonHidden(true)
                    .navigationBarHidden(true)
                    
                case .groupName:
                    GroupNameView(selectedContacts: $participants) { groupName, displayImage, groupParticipants in
                        onComplete?(groupName, displayImage)
                    } onDismiss: {
                        onDismiss?()
                    }
                    .navigationBarBackButtonHidden(true)
                    .navigationBarHidden(true)
                }
            }
        }
        .navigationBarBackButtonHidden(true) // Also on root
        .navigationBarHidden(true)
    }

    // MARK: - Header View
    private func headerView() -> some View {
        HStack(alignment: .center, spacing: BlockedUserScreen.rowSpacing) {
//            Button(action: {
//                // Action for back button
//            }) {
//                Image("back-long")
//                    .resizable()
//                    .frame(width: 24, height: 24)
//            }
            
            VStack(alignment: .leading, spacing: UIConstants.Layout.tightSpacing) {
                Text(Constants.selectContact.rawValue)
                    .font(Design.Font.bold(UIConstants.Layout.menuItemIconSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                
                Text("\(viewModel.yalContacts.count) \(Constants.yalContact.rawValue)")
                    .font(Design.Font.medium(BlockedUserScreen.rowSpacing))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Layout.color1))
            }
            .padding(.leading)
            
            Spacer()
            
            Button(action: {
                onDismiss?()
            }) {
                Image(Constants.crossBlack.rawValue)
                    .frame(width: UIConstants.Layout.Radius.large, height: UIConstants.Layout.Radius.large)
                    .aspectRatio(contentMode: .fit)
            }
            .padding(.top,CGFloat(UIConstants.Layout.topPaddinglagging))
        }
        .background(Design.Color.backgroundColor)
        .padding(.horizontal, UIConstants.Layout.screenPadding)
        .padding(.top, ChatLayout.viewTopPad)
    }

    // MARK: - Search Bar View
    private func searchBarView() -> some View {
        SearchBarView(placeholder: Constants.searchPlaceholderText.rawValue, text: $viewModel.search)
            .padding(.horizontal,  UIConstants.Layout.screenPadding)
            .frame(maxHeight: UIConstants.Layout.Height.tapTarget)
            .padding(.top,  UIConstants.Layout.screenPadding)
    }

    // MARK: - Content Section (buttons, separator, and contact list)
    private func contentSection() -> some View {
        List {
            // New Group and New Contact buttons
            buttonsSection()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Design.Color.backgroundColor)

            if !viewModel.filteredYalContacts.isEmpty {
                // First Group: Contacts with userId
                Section(
                    header: Text(Constants.contactOnYalAi.rawValue)
                        .font(Design.Font.heavy(UIConstants.Layout.menuItemIconSpacing))
                        .foregroundColor(Design.Color.primaryTextColor)
                        .padding(.top, UIConstants.Layout.zeroSpacing)
                        .padding(.bottom,  UIConstants.Layout.screenPadding)
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Design.Color.backgroundColor)

                ) {
                    ForEach(viewModel.filteredYalContacts) { contact in
                        ContactRow(contact: contact)
                            .listRowBackground(Design.Color.backgroundColor)

                            .onTapGesture {
                                participants.append(contact)
                                onComplete?(nil, nil)
                            }
                            .listRowBackground(Design.Color.backgroundColor)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal,  UIConstants.Layout.screenPadding)
                .padding(.bottom, UIConstants.Layout.Radius.small)
                .background(Design.Color.backgroundColor)
            }

            // Second Group: Contacts without userId
            Section(
                header: Text(Constants.inviteOnYalAi.rawValue)
                    .font(Design.Font.heavy(UIConstants.Layout.menuItemIconSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .padding(.top, BlockedUserScreen.rowSpacing)
                    .padding(.bottom,  UIConstants.Layout.screenPadding)
                    .listRowInsets(EdgeInsets())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Design.Color.backgroundColor)

            ) {
                ForEach(viewModel.filteredOtherContacts) { contact in
                    ContactRow(
                        contact: contact,
                        showInviteButton: true,
                        onInviteTap: {
                            print("\(Constants.inviteTapped.rawValue) \(contact.fullName ?? "")")
                            invitedContacts.append(contact)
                        }
                    )
                    .listRowBackground(Design.Color.backgroundColor)
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal,  UIConstants.Layout.screenPadding)
            .background(Design.Color.backgroundColor)
        }
        .listRowSpacing(UIConstants.Layout.innerBottomSpacing)
        .environment(\.defaultMinListRowHeight, UIConstants.Layout.Radius.small)
        .frame(maxWidth: .infinity)
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)  // Add this - hides default List background
        .background(Design.Color.backgroundColor)
    }

    // MARK: - Buttons Section (New Group and New Contact)
    private func buttonsSection() -> some View {
        VStack(spacing: UIConstants.Layout.zeroSpacing) {
            // New Group Button
            Button(action: {
                navPath.append(GroupCreateRoute.groupSelect)
            }) {
                HStack(spacing: BlockedUserScreen.rowSpacing) {
                    Image(Constants.newGroup.rawValue)
                        .resizable()
                        .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
                    Text(Constants.newGroup1.rawValue)
                        .font(Design.Font.semiBold(UIConstants.Layout.menuItemIconSpacing))
                        .foregroundColor(Design.Color.primaryTextColor)
                    
                    Spacer()
                }
                .padding(.horizontal,  UIConstants.Layout.screenPadding)
                .padding(.vertical,  UIConstants.Layout.Radius.small)
                .background(Design.Color.backgroundColor)
            }
            .buttonStyle(.plain)
            
            // New Contact Button
            Button(action: {
                // Add your New Contact action here
            }) {
                HStack(spacing: BlockedUserScreen.rowSpacing) {
                    Image(Constants.newContact.rawValue)   // Replace with your asset name when added
                        .resizable()
                        .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
                    Text(Constants.newContact1.rawValue)
                        .font(Design.Font.semiBold(UIConstants.Layout.menuItemIconSpacing))
                        .foregroundColor(Design.Color.primaryTextColor)
                    
                    Spacer()
                }
                .padding(.horizontal,  UIConstants.Layout.screenPadding)
                .padding(.vertical,  UIConstants.Layout.Radius.small)
                .background(Design.Color.backgroundColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, UIConstants.Layout.zeroSpacing)
        .padding(.bottom,  UIConstants.Layout.zeroSpacing)
    }

    // MARK: - Separator View
    private func separatorView() -> some View {
        Rectangle()
            .fill(Design.Color.appGradient.opacity(UIConstants.Layout.color4))
            .frame(height:  UIConstants.Layout.Radius.small)

    }
}

struct ContactRow: View {
    let contact: ContactLite
    var showInviteButton: Bool = false
    var onInviteTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: BlockedUserScreen.rowSpacing) {
            // Avatar
            if let imageURLString = contact.avatarURL {
                MediaView(
                    mediaURL: imageURLString,
                    userName: "",
                    timeText: "",
                    mediaType: .image,
                    placeholder: placeholderInitialsView,
                    errorView: placeholderInitialsView,
                    isSender: false,
                    downloadedImage: nil,
                    senderImage: "",
                    localURLOverride: nil
                )
                .scaledToFill()
                .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
                .clipShape(Circle())
            } else if let imageURLString = contact.imageURL {
                MediaView(
                    mediaURL: imageURLString,
                    userName: "",
                    timeText: "",
                    mediaType: .image,
                    placeholder: placeholderInitialsView,
                    errorView: placeholderInitialsView,
                    isSender: false,
                    downloadedImage: nil,
                    senderImage: "",
                    localURLOverride: nil
                )
                .scaledToFill()
                .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
                .clipShape(Circle())
            } else if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
                    .clipShape(Circle())
            } else {
                // Generate a placeholder with initials
                Text(getInitials(from: contact.fullName ?? ""))
                    .font(.system(size: UIConstants.Layout.menuOptionVPadding, weight: .bold))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Layout.ProfileView.AboutSection.editorOpacity))
                    .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)  // Set the circle size
                    .background(contact.randomeProfileColor.opacity(UIConstants.Opacity.overlay))
                    .clipShape(Circle())
            }
            
            // MARK: Name + Phone
            VStack(alignment: .leading, spacing: UIConstants.Layout.tightSpacing) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(UIConstants.Layout.menuItemIconSpacing))
                    .foregroundColor(Design.Color.primaryTextColor)
                Text(contact.phoneNumber)  // Placeholder for actual status
                    .font(Design.Font.regular(BlockedUserScreen.rowSpacing))
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Layout.color1))
            }
            Spacer()
                if showInviteButton {
                Button {
                    shareApp()
                } label: {
                    Text(Constants.invite.rawValue)
                        .font(Design.Font.medium(BlockedUserScreen.rowSpacing))
                        .foregroundColor(.white)
                        .frame(width: UIConstants.Layout.wideScreenPadding, height:  UIConstants.Layout.screenPadding)
                        .background(Color(hex: UIConstants.Layout.EditProfile.selectContactBgColor))
                        .cornerRadius( UIConstants.Layout.ProfileView.CameraButton.strokeWidth)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical,  UIConstants.Layout.ProfileView.ProfileImage.shadowRadius)
        .background(Design.Color.backgroundColor)
    }
    
    private var placeholderInitialsView: some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(UIConstants.Layout.Radius.small))
            .frame(width: UIConstants.Layout.wideScreenPadding, height: UIConstants.Layout.wideScreenPadding)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Layout.ProfileView.AboutSection.editorOpacity))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Design.Color.white, lineWidth: UIConstants.Layout.deleteButtonBorderWidth)
            )
    }
}
private func shareApp() {
    let shareText = Constants.shareItemStr.rawValue
    let activityVC = UIActivityViewController(
        activityItems: [shareText],
        applicationActivities: nil
    )

    // Get the current top-most view controller and present
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = windowScene.windows.first?.rootViewController {
        
        // Handle iPad popover (required or it crashes on iPad)
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: rootVC.view.bounds.midX,
            y: rootVC.view.bounds.midY,
            width:  UIConstants.Layout.zeroSpacing,
            height:  UIConstants.Layout.zeroSpacing
        )
        activityVC.popoverPresentationController?.permittedArrowDirections = []

        rootVC.present(activityVC, animated: true)
    }
}

