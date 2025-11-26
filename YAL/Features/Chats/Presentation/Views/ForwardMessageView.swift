//
//  ForwardMessageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 18/06/25.
//

import SwiftUI
import SDWebImageSwiftUI

// MARK: - Main Forward Message View

struct ForwardMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ForwardMessageViewModel
    let messageToForward: [ChatMessageModel]
    var onComplete: (() -> Void)?
    
    init(
        messageToForward: [ChatMessageModel],
        onComplete: (() -> Void)? = nil
    ) {
        let vm = DIContainer.shared.container.resolve(ForwardMessageViewModel.self)!
        _viewModel = StateObject(wrappedValue: vm)
        self.messageToForward = messageToForward
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerSection
                searchBarView()
                ScrollView {
                    VStack(alignment: .leading) {
                        section(title: "Frequently contacted", targets: viewModel.frequentChats.map { .room($0) })
                        section(title: "Recent Chats", targets: viewModel.recentChats.map { .room($0) })
                        section(title: "Contacts on YAL.ai", targets: viewModel.yalContacts.map { .contact($0) })
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, viewModel.selectedTargets.count > 0 ? 155 : 20)
                }
            }
            if viewModel.selectedTargets.count > 0 {
                bottomBar
            }
            if LoaderManager.shared.isLoading {
                LoaderView()
            }
        }
        .background(Color(red: 0.92, green: 0.96, blue: 1.0).ignoresSafeArea())
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Header
    var headerSection: some View {
        HStack(spacing: 12) {
            Text("Forward Message")
                .font(Design.Font.semiBold(14))
                .foregroundColor(Design.Color.primaryText)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image("cross-black")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .padding(.top, 52)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .background(Color.white)
        .zIndex(2)
    }
    
    // MARK: - Search Bar
    private func searchBarView() -> some View {
        SearchBarView(placeholder: "Search numbers, names & more", text: $viewModel.searchText)
            .padding(.horizontal, 20)
            .frame(maxHeight: 44)
            .padding(.vertical, 20)
    }
    
    // MARK: - Section Builder
    func section(title: String, targets: [ForwardTarget]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !targets.isEmpty {
                Text(title)
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.primaryText)
            }
            ForEach(targets, id: \.id) { target in
                row(for: target)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Row Builder
    @ViewBuilder
    func row(for target: ForwardTarget) -> some View {
        let isSelected = viewModel.selectedTargets.contains(target)
        switch target {
        case .room(let room):
            SelectableRowView(
                title: room.name,
                subtitle: room.opponent?.statusMessage ?? "",
                imageURL: room.avatarUrl,
                isSelected: isSelected) {
                    viewModel.toggleSelection(target: target)
                }
        case .contact(let contact):
            SelectableRowView(
                title: contact.fullName ?? "",
                subtitle: contact.about ?? "",
                imageURL: contact.avatarURL,
                isSelected: isSelected) {
                    viewModel.toggleSelection(target: target)
                }
        }
    }
    
    // MARK: - Bottom Bar
    var bottomBar: some View {
        VStack(spacing: 0) {
            Text("\(viewModel.selectedTargets.count) selected")
                .font(Design.Font.semiBold(14))
                .foregroundColor(Design.Color.primaryText)
                .padding(.top, 20)
            
            Spacer().frame(height: 20)
            
            HStack(spacing: 20) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(Design.Font.regular(14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Design.Color.lightGrayBackground)
                        .foregroundColor(Design.Color.primaryText)
                        .cornerRadius(8)
                }
                Button(action: {
                    if messageToForward.count == 1 {
                        viewModel.forwardMessage(message: messageToForward.first!) {
                            onComplete?()
                            dismiss()
                        }
                    } else {
                        viewModel.forwardMultipleMessage(messages: messageToForward) {
                            onComplete?()
                            dismiss()
                        }
                    }
                }) {
                    Text("Continue")
                        .font(Design.Font.semiBold(14))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Design.Color.appGradient)
                        .foregroundColor(Design.Color.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial) // Native blurred background
                .background(Color.white.opacity(0.2)) // Light white tint
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -4)
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Selectable Row View

struct SelectableRowView: View {
    let title: String
    let subtitle: String?
    let imageURL: String?
    let isSelected: Bool
    let toggleAction: () -> Void

    var body: some View {
        Button(action: toggleAction) {
            HStack(spacing: 12) {
                ZStack(alignment: .center) {
                    if let url = imageURL, let imgURL = URL(string: url) {
                        WebImage(url: imgURL)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(getInitials(from: title))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.black)
                            )
                    }
                    if isSelected {
                        Image("tick-circle")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .background(Design.Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Design.Color.white, lineWidth: 1))
                            .offset(x: 12, y: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Design.Font.semiBold(14))
                        .foregroundColor(Design.Color.primaryText)
                    
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Design.Font.semiBold(12))
                            .foregroundColor(Design.Color.primaryText.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // Prevents blue highlight on tap
    }
}
