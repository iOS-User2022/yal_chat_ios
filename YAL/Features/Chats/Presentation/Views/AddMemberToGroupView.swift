//
//  AddMemberToGroupView.swift
//  YAL
//
//  Created by Vishal Bhadade on 05/07/25.
//


import SwiftUI
import SDWebImageSwiftUI

struct AddMemberToGroupView: View {
    @ObservedObject var viewModel: SelectContactListViewModel
    @Binding var selectedContacts: [ContactLite]
    let currentGroupMembers: [ContactLite]
    @Environment(\.dismiss) private var dismiss

    var onContinue: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    
                    Text("Add member")
                        .font(Design.Font.bold(16))
                        .foregroundColor(Design.Color.primaryText)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image("cross-white")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // Search bar
                SearchBarView(placeholder: "Search numbers, names & more", text: $viewModel.search)
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
                    // Frequently contacted section
                    if !viewModel.filteredFrequentlyContacted.isEmpty {
                        Section(header: Text("Frequently contacted")
                            .font(Design.Font.bold(14))
                            .foregroundColor(Design.Color.primaryText)) {
                                ForEach(viewModel.filteredFrequentlyContacted) { contact in
                                    AddGroupContactRow(
                                        contact: contact,
                                        isSelected: selectedContacts.contains(contact),
                                        isAlreadyMember: currentGroupMembers.contains(contact),
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

                    if !viewModel.filteredYalContacts.isEmpty {
                        Section(header: Text("Contact on YAL.ai")) {
                            ForEach(viewModel.filteredYalContacts) { contact in
                                AddGroupContactRow(
                                    contact: contact,
                                    isSelected: selectedContacts.contains(contact),
                                    isAlreadyMember: currentGroupMembers.contains(contact),
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
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 48)
            }

            // Bottom bar
            VStack(spacing: 20) {
                Text("\(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s") selected")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)

                HStack(spacing: 20) {
                    Button("Cancel") { onDismiss?() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Design.Color.lightWhiteBackground)
                        .cornerRadius(8)
                    
                    Button("Continue") {
                        onContinue?()
                    }
                    .disabled(selectedContacts.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedContacts.isEmpty ? Design.Color.appGradient.opacity(0.6) : Design.Color.appGradient.opacity(1.0))
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
                    .fill(.ultraThinMaterial)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -4)
            )
        }
        .background(Design.Color.white)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func avatarView(for contact: ContactLite) -> some View {
        if let imageURLString = contact.imageURL, let imageURL = URL(string: imageURLString) {
            WebImage(url: imageURL, options: [.retryFailed, .continueInBackground])
                .resizable()
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
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(contact.randomeProfileColor)
                .clipShape(Circle())
        }
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

struct AddGroupContactRow: View {
    let contact: ContactLite
    let isSelected: Bool
    let isAlreadyMember: Bool
    let addAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // ... (use your avatarView code)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.fullName ?? "")
                    .font(Design.Font.bold(14))
                    .foregroundColor(Design.Color.primaryText)
                Text(contact.about ?? "")
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if isAlreadyMember {
                Text("Already added to the group")
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    .font(Design.Font.regular(12))
                    .padding(4)
            } else if isSelected {
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
}
