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
            .background(Design.Color.white)
            .onAppear {
                
                viewModel.startContactSync()
            }
            .navigationDestination(for: GroupCreateRoute.self) { route in
                switch route {
                case .groupSelect:
                    NewGroupContactSelectorView(viewModel: viewModel, selectedContacts: $participants, invitedContacts: $invitedContacts) {
                        print("contcts selected")
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
        HStack(alignment: .center, spacing: 12) {
//            Button(action: {
//                // Action for back button
//            }) {
//                Image("back-long")
//                    .resizable()
//                    .frame(width: 24, height: 24)
//            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Contact")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)
                
                Text("\(viewModel.yalContacts.count) Yal contacts")
                    .font(Design.Font.medium(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
            }
            .padding(.leading)
            
            Spacer()
            
            Button(action: {
                onDismiss?()
            }) {
                Image("cross-black")
                    .frame(width: 24, height: 24)
                    .aspectRatio(contentMode: .fit)
            }
            .padding(.top,-40)
        }
        .background(Design.Color.white)
        .padding(.horizontal, 20)
        .padding(.top, 56)
    }

    // MARK: - Search Bar View
    private func searchBarView() -> some View {
        SearchBarView(placeholder: "Search numbers, names & more", text: $viewModel.search)
            .padding(.horizontal, 20)
            .frame(maxHeight: 44)
            .padding(.top, 20)
    }

    // MARK: - Content Section (buttons, separator, and contact list)
    private func contentSection() -> some View {
        List {
            // New Group and New Contact buttons
            buttonsSection()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            
            if !viewModel.filteredYalContacts.isEmpty {
                // First Group: Contacts with userId
                Section(
                    header: Text("Contact on YAL.ai")
                        .font(Design.Font.heavy(14))
                        .foregroundColor(Design.Color.primaryText)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                ) {
                    ForEach(viewModel.filteredYalContacts) { contact in
                        ContactRow(contact: contact)
                            .onTapGesture {
                                participants.append(contact)
                                onComplete?(nil, nil)
                            }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                separatorView()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            // Second Group: Contacts without userId
            Section(
                header: Text("Invite on YAL.ai")
                    .font(Design.Font.heavy(14))
                    .foregroundColor(Design.Color.primaryText)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            ) {
                ForEach(viewModel.filteredOtherContacts) { contact in
                    ContactRow(contact: contact)
                        .onTapGesture {
                            //participants.append(contact)
                        }
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal, 20)
        }
        .listRowSpacing(20)
        .environment(\.defaultMinListRowHeight, 8)
        .frame(maxWidth: .infinity)
        .listStyle(PlainListStyle())
    }

    // MARK: - Buttons Section (New Group and New Contact)
    private func buttonsSection() -> some View {
        VStack(spacing: 0) {
            Button(action: {
                navPath.append(GroupCreateRoute.groupSelect)
            }) {
                HStack {
                    Image("new-group")
                        .resizable()
                        .frame(width: 48, height: 48)
                    Text("New Group")
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.primaryText)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .background(Design.Color.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            
//            Button(action: {
//                // Action for new contact
//            }) {
//                HStack(alignment: .center, spacing: 12) {
//                    Image("new-contact")
//                        .resizable()
//                        .frame(width: 48, height: 48)
//
//                    Text("New Contact")
//                        .font(Design.Font.bold(14))
//                        .foregroundColor(Design.Color.primaryText)
//                    
//                    Spacer()
//                }
//                .frame(maxWidth: .infinity)
//                .font(.subheadline)
//                .foregroundColor(.blue)
//            }
//            .background(Design.Color.white)
//            .frame(maxWidth: .infinity)
//            .padding(.horizontal, 20)
//            .padding(.vertical, 8)
            
            // Separator
            separatorView()
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 16)
    }

    // MARK: - Separator View
    private func separatorView() -> some View {
        Rectangle()
            .fill(Design.Color.appGradient.opacity(0.12))
            .frame(height: 8)

    }
}

struct ContactRow: View {
    let contact: ContactLite
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                // Generate a placeholder with initials
                Text(getInitials(from: contact.fullName ?? ""))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
                    .frame(width: 40, height: 40)  // Set the circle size
                    .background(contact.randomeProfileColor.opacity(0.3))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)
                Text(contact.phoneNumber)  // Placeholder for actual status
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
            }
            Spacer()
        }
    }
}
