//
//  NewGroupContactSelectorView.swift
//  YAL
//
//  Created by Vishal Bhadade on 22/05/25.
//


import SwiftUI
import SDWebImageSwiftUI

struct NewGroupContactSelectorView: View {
    @ObservedObject var selectContactListViewModel: SelectContactListViewModel
    @Binding var selectedContacts: [ContactLite]
    @Binding var invitedContacts: [ContactLite]
    @Environment(\.dismiss) private var dismiss
    @State private var isKeyboardVisible: Bool = false
    
    var onContinue: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init(viewModel: SelectContactListViewModel, selectedContacts: Binding<[ContactLite]>, invitedContacts: Binding<[ContactLite]>, onContinue: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        selectContactListViewModel = viewModel
        
        self._selectedContacts = selectedContacts
        self._invitedContacts = invitedContacts
        self.onContinue = onContinue
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image("back-long")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New group")
                            .font(Design.Font.bold(16))
                            .foregroundColor(Design.Color.primaryText)
                        Text("You can add upto 200 members")
                            .font(Design.Font.medium(12))
                            .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    }
                    Spacer()
                    Button(action: { /* Info action */ }) {
                        Image("info-circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // Search bar
                SearchBarView(placeholder: "Search numbers, names & more", text: $selectContactListViewModel.search)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .padding(.top, 20)


                // Selected contacts avatar row
                if !selectedContacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(selectedContacts) { contact in
                                VStack {
                                    ZStack(alignment: .topTrailing) {
                                        avatarView(for: contact)
                                            
                                        Button(action: {
                                            if let idx = selectedContacts.firstIndex(of: contact) {
                                                selectedContacts.remove(at: idx)
                                            }
                                        }) {
                                            Image("cross-circle")
                                                .foregroundColor(.white)
                                                .frame(width: 22, height: 22)
                                        }
                                        .offset(x: 6, y: 18)
                                    }
                                    Text(contact.fullName ?? "")
                                        .font(Design.Font.bold(10))
                                        .foregroundColor(Design.Color.primaryText)
                                        .frame(maxWidth: 48)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .transition(.move(edge: .top))
                }

                separatorView()

                // Contacts list
                List {
                    // Frequently contacted section (if available)
                    if !selectContactListViewModel.filteredFrequentlyContacted.isEmpty {
                        Section(header: Text("Frequently contacted")
                            .font(Design.Font.bold(14))
                            .foregroundColor(Design.Color.primaryText)) {
                                ForEach(selectContactListViewModel.filteredFrequentlyContacted) { contact in
                                    ContactSelectRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact),
                                        addAction: {
                                            if !selectedContacts.contains(contact) {
                                                selectedContacts.append(contact)
                                            }
                                        },
                                        removeAction: {
                                            selectedContacts.removeAll { $0 == contact }
                                        }
                                    )
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .padding(.horizontal, 20)
                        
                        separatorView()
                    }
                    
                    if !selectContactListViewModel.filteredYalContacts.isEmpty {
                        Section(header: Text("Contact on YAL.ai")) {
                            ForEach(selectContactListViewModel.filteredYalContacts) { contact in
                                ContactSelectRow(
                                    contact: contact,
                                    isSelected: selectedContacts.contains(contact),
                                    addAction: {
                                        if !selectedContacts.contains(contact) {
                                            selectedContacts.append(contact)
                                        }
                                    },
                                    removeAction: {
                                        selectedContacts.removeAll { $0 == contact }
                                    }
                                )
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .padding(.horizontal, 20)
                        
                        separatorView()
                    }
                    
                    // All contacts section
                    Section(header: Text("Other Contacts")) {
                        ForEach(selectContactListViewModel.filteredOtherContacts) { contact in
                            OtherContactInviteRow(contact: contact, isInvited: invitedContacts.contains(contact)) {
                                invitedContacts.append(contact)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .padding(.horizontal, 20)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 48)
            }
            
            // Bottom bar
            if !isKeyboardVisible {
            VStack(spacing: 20) {
                if selectedContacts.count < 1 {
                    Text("Add contacts to continue")
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.primaryText)
                } else {
                    Text("\(selectedContacts.count) contact\(selectedContacts.count > 1 ? "s" : "") selected")
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.primaryText)
                }
                
                
                HStack(spacing: 20) {
                    Button("Cancel") { onDismiss?() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Design.Color.lightWhiteBackground)
                        .cornerRadius(8)
                    Button("Continue") {
                        onContinue?()
                    }
                    .disabled(selectedContacts.count < 1)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedContacts.count >= 1 ? Design.Color.appGradient.opacity(1.0) : Design.Color.appGradient.opacity(0.6))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial) // Native blurred background
                    .background(Color.white.opacity(0.6)) // Light white tint
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -4)
            )
        }
    }
        .background(Design.Color.white)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        
        
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation {
                isKeyboardVisible = false
            }
        }

    }

    // Avatar helper
    @ViewBuilder
    private func avatarView(for contact: ContactLite) -> some View {
        if let imageURLString = contact.avatarURL {
            MediaView(
                mediaURL: imageURLString,
                userName: "",
                timeText: "",
                mediaType: .image,
                placeholder: placeholderInitialsView(for: contact),
                errorView: placeholderInitialsView(for: contact),
                isSender: false,
                downloadedImage: nil,
                senderImage: "",
                localURLOverride: nil
            )
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else if let imageURLString = contact.imageURL {
            MediaView(
                mediaURL: imageURLString,
                userName: "",
                timeText: "",
                mediaType: .image,
                placeholder: placeholderInitialsView(for: contact),
                errorView: placeholderInitialsView(for: contact),
                isSender: false,
                downloadedImage: nil,
                senderImage: "",
                localURLOverride: nil
            )
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Text(getInitials(from: contact.fullName ?? ""))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
                .frame(width: 40, height: 40)  // Set the circle size
                .background(contact.randomeProfileColor.opacity(0.3))
                .clipShape(Circle())
        }
    }
    
    private func placeholderInitialsView(for contact: ContactLite) -> some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(8))
            .frame(width: 40, height: 40)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryText.opacity(0.7))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Design.Color.white, lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func separatorView() -> some View {
        Rectangle()
            .fill(Design.Color.appGradient.opacity(0.12))
            .frame(height: 8)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        
    }
}

struct ContactSelectRow: View {
    let contact: ContactLite
    let isSelected: Bool
    let addAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .center) {
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
                    .frame(width: 40, height: 40)
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
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: contact.fullName ?? ""))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Color.primaryText.opacity(0.7))
                        .frame(width: 40, height: 40)  // Set the circle size
                        .background(contact.randomeProfileColor.opacity(0.3))
                        .clipShape(Circle())
                }
                
                if isSelected {
                    Button(action: {
                        removeAction()
                    }) {
                        Image("tick-circle")
                            .background(.white)
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Design.Color.white, lineWidth: 1))
                    }
                    .offset(x: 12, y: 12)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(contact.about ?? "")
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            if isSelected {
                Button(action: removeAction) {
                    Text("Added")
                        .foregroundColor(Design.Color.white)
                        .font(Design.Font.bold(12))
                        .padding(4)
                }
                .background(Design.Color.greenGradient)
                .cornerRadius(2)
                
            } else {
                Button(action: addAction) {
                    Text("Add")
                        .foregroundColor(Design.Color.white)
                        .font(Design.Font.bold(12))
                        .padding(4)
                }
                .background(Design.Color.blueGradient)
                .cornerRadius(2)

            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private var placeholderInitialsView: some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(8))
            .frame(width: 40, height: 40)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryText.opacity(0.7))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Design.Color.white, lineWidth: 1)
            )
    }
}

struct OtherContactInviteRow: View {
    let contact: ContactLite
    let isInvited: Bool
    let onInviteTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .center) {
                if let imageURLString = contact.imageURL, let imageURL = URL(string: imageURLString) {
                    WebImage(url: imageURL, options: [.retryFailed, .continueInBackground])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: contact.fullName ?? ""))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Color.primaryText.opacity(0.7))
                        .frame(width: 40, height: 40)  // Set the circle size
                        .background(contact.randomeProfileColor.opacity(0.3))
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(contact.about ?? "")
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)

            }
            .frame(maxWidth: .infinity)

            Spacer()

            Button(action: {
                if !isInvited {
                    onInviteTapped()
                }
            }) {
                Text(isInvited ? "Invited" : "Invite")
                    .foregroundColor(Design.Color.white)
                    .font(Design.Font.bold(12))
                    .padding(4)
            }
            .background(isInvited ? Design.Color.greenGradient : Design.Color.blueGradient)
            .cornerRadius(2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}
