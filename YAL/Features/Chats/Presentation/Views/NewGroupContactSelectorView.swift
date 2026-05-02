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
                    Button(action: {
                        onDismiss?()
                        dismiss()
                    }) {
                        Image("back-long")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(Design.Color.primaryTextColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New group")
                            .font(Design.Font.bold(18))
                            .foregroundColor(Design.Color.primaryTextColor)
                        Text("You can add upto 200 members")
                            .font(Design.Font.regular(12))
                            .foregroundColor(Design.Color.primaryTextColor).opacity(0.5)
                    }
                    Spacer()
                    Button(action: {}) {
                        Image("info-circle")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 22, height: 22)
                            .foregroundColor(Design.Color.primaryTextColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 5)
                .padding(.bottom, 16)

                // Search bar
                SearchBarView(placeholder: "Search numbers, names & more", text: $selectContactListViewModel.search)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Selected contacts avatar row
                if !selectedContacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedContacts) { contact in
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        avatarView(for: contact)
                                            .frame(width: 48, height: 48)
                                        
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if let idx = selectedContacts.firstIndex(of: contact) {
                                                    selectedContacts.remove(at: idx)
                                                }
                                            }
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 22, height: 22)
                                                Image("x-small")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .offset(x: 1, y: -1)
                                    }
                                    
                                    Text(contact.fullName?.components(separatedBy: " ").first ?? "")
                                        .font(Design.Font.semiBold(8))
                                        .foregroundColor(Design.Color.primaryTextColor)
                                        .frame(maxWidth: 48)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 5)
                    }
                    .background(Design.Color.backgroundColor)
                }

                // Contacts list
                ScrollView {
                    VStack(spacing: 0) {
                        // Frequently contacted section
                        if !selectContactListViewModel.filteredFrequentlyContacted.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Frequently contacted")
                                    .font(Design.Font.bold(14))
                                    .foregroundColor(Design.Color.primaryTextColor)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                
                                ForEach(selectContactListViewModel.filteredFrequentlyContacted) { contact in
                                    ContactSelectRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact),
                                        addAction: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if !selectedContacts.contains(contact) {
                                                    selectedContacts.append(contact)
                                                }
                                            }
                                        },
                                        removeAction: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedContacts.removeAll { $0 == contact }
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Contact on YAL.ai section
                        if !selectContactListViewModel.filteredYalContacts.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Contact on YAL.ai")
                                    .font(Design.Font.bold(14))
                                    .foregroundColor(Design.Color.primaryTextColor)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                    .padding(.bottom, 12)
                                
                                ForEach(selectContactListViewModel.filteredYalContacts) { contact in
                                    ContactSelectRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact),
                                        addAction: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if !selectedContacts.contains(contact) {
                                                    selectedContacts.append(contact)
                                                }
                                            }
                                        },
                                        removeAction: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedContacts.removeAll { $0 == contact }
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Invite on YAL.ai section
                        if !selectContactListViewModel.filteredOtherContacts.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Invite on YAL.ai")
                                    .font(Design.Font.bold(14))
                                    .foregroundColor(Design.Color.primaryTextColor)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                    .padding(.bottom, 12)
                                
                                ForEach(selectContactListViewModel.filteredOtherContacts) { contact in
                                    OtherContactInviteRow(
                                        contact: contact,
                                        isInvited: invitedContacts.contains(contact)
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if !invitedContacts.contains(contact) {
                                                invitedContacts.append(contact)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Invite on YAL.ai section with action buttons
                        VStack(alignment: .leading, spacing: 0) {
                           
                            // Share Invite link button
                            Button(action: {
                                // Handle share invite link action
                                shareInviteLink()
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Design.Color.lightWhiteBackground)
                                            .frame(width: 48, height: 48)
                                        
                                        Image("share")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(Design.Color.primaryTextColor)
                                    }
                                    
                                    Text("Share Invite link")
                                        .font(Design.Font.bold(15))
                                        .foregroundColor(Design.Color.primaryTextColor)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }
                            
                            // Contact Help button
                            Button(action: {
                                // Handle contact help action
                                contactHelp()
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Design.Color.lightWhiteBackground)
                                            .frame(width: 48, height: 48)
                                        
                                        Image("profile-add")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(Design.Color.primaryTextColor)
                                    }
                                    
                                    Text("Contact Help")
                                        .font(Design.Font.bold(15))
                                        .foregroundColor(Design.Color.primaryTextColor)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }
                        }
                        
                        // Bottom padding for button
                        Spacer()
                            .frame(height: 140)
                    }
                }
            }
            
            // Bottom bar - Updated button styling
            if !isKeyboardVisible {
                VStack(spacing: 0) {
                    // Contact count or message
                    Text(selectedContacts.count >= 1
                        ? "\(selectedContacts.count) contact\(selectedContacts.count > 1 ? "s" : "") selected"
                        : "Add contacts to continue")
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.primaryTextColor)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    // Action buttons - Updated to match GroupNameView
                    HStack(spacing: 12) {
                        Button(action: {
                            onDismiss?()
                            dismiss()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                        }
                        
                        Button(action: {
                            onContinue?()
                        }) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.3, green: 0.4, blue: 1.0),
                                                    Color(red: 0.55, green: 0.36, blue: 0.96)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .opacity(selectedContacts.count < 1 ? 0.5 : 1.0)
                                )
                        }
                        .disabled(selectedContacts.count < 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(Design.Color.darkgrayColor))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -4)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .background(Design.Color.backgroundColor)
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
            .frame(width: 48, height: 48)
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
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            Text(getInitials(from: contact.fullName ?? ""))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Design.Color.primaryTextColor).opacity(0.7)
                .frame(width: 48, height: 48)
                .background(contact.randomeProfileColor).opacity(0.3)
                .clipShape(Circle())
        }
    }
    
    private func placeholderInitialsView(for contact: ContactLite) -> some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(10))
            .frame(width: 48, height: 48)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryTextColor).opacity(0.7)
            .clipShape(Circle())
    }
    
    // MARK: - Action Functions
    private func shareInviteLink() {
        // Generate or get the invite link
        let inviteLink = "https://yal.ai/invite/your-invite-code" // Replace with actual invite link
        
        // Create activity view controller to share
        let activityVC = UIActivityViewController(
            activityItems: ["Join me on YAL.ai! \(inviteLink)"],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func contactHelp() {
        // Handle contact help action
        if let url = URL(string: "mailto:support@yal.ai?subject=Need Help with Group Creation") {
            UIApplication.shared.open(url)
        }
        
        print("Contact Help tapped")
    }
}

// MARK: - Contact Select Row
struct ContactSelectRow: View {
    let contact: ContactLite
    let isSelected: Bool
    let addAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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
                    .frame(width: 48, height: 48)
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
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: contact.fullName ?? ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.7)
                        .frame(width: 48, height: 48)
                        .background(contact.randomeProfileColor).opacity(0.3)
                        .clipShape(Circle())
                }
            }
            
            // Contact info
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(15))
                    .foregroundColor(Design.Color.primaryTextColor)
                
                if !contact.phoneNumber.isEmpty {
                    Text(contact.phoneNumber)
                        .font(Design.Font.regular(13))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.5)
                }
            }
            
            Spacer()
            
            // Checkbox - Updated with overlay
            Button(action: {
                if isSelected {
                    removeAction()
                } else {
                    addAction()
                }
            }) {
                ZStack {
                    // Background checkbox (always visible)
                    Image("checkbox_empty")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 22, height: 22)
                        .foregroundColor(Design.Color.primaryTextColor.opacity(0.3))
                    
                    // Green tick overlay (only when selected)
                    if isSelected {
                        Image("green_tick")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 14, height: 14)
                            .foregroundColor(Color.green)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                removeAction()
            } else {
                addAction()
            }
        }
    }
    
    private var placeholderInitialsView: some View {
        return Text(getInitials(from: contact.fullName ?? contact.displayName ?? contact.phoneNumber))
            .font(Design.Font.bold(10))
            .frame(width: 48, height: 48)
            .background(randomBackgroundColor())
            .foregroundColor(Design.Color.primaryTextColor).opacity(0.7)
            .clipShape(Circle())
    }
}

// MARK: - Other Contact Invite Row
struct OtherContactInviteRow: View {
    let contact: ContactLite
    let isInvited: Bool
    let onInviteTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack(alignment: .center) {
                if let imageURLString = contact.imageURL, let imageURL = URL(string: imageURLString) {
                    WebImage(url: imageURL, options: [.retryFailed, .continueInBackground])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else if let imageData = contact.imageData, let img = UIImage(data: imageData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: contact.fullName ?? ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.7)
                        .frame(width: 48, height: 48)
                        .background(contact.randomeProfileColor).opacity(0.3)
                        .clipShape(Circle())
                }
            }

            // Contact info
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(15))
                    .foregroundColor(Design.Color.primaryTextColor)

                if !contact.phoneNumber.isEmpty {
                    Text(contact.phoneNumber)
                        .font(Design.Font.regular(13))
                        .foregroundColor(Design.Color.primaryTextColor).opacity(0.5)
                }
            }

            Spacer()

            // Invite button - Updated to match new design
            Button(action: {
                if !isInvited {
                    onInviteTapped()
                }
            }) {
                Text(isInvited ? "Invited" : "Invite")
                    .font(Design.Font.bold(13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.3, green: 0.4, blue: 1.0),
                                        Color(red: 0.55, green: 0.36, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(isInvited ? 0.5 : 1.0)
                    )
            }
            .disabled(isInvited)
        }
        .padding(.vertical, 10)
    }
}
