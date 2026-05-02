//
//  BlockedUserListView.swift
//  YAL
//
//  Created by Hari krishna on 06/02/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct BlockedUserListView: View {
    @ObservedObject var roomViewModel: RoomListViewModel
    @State private var showUnBlock = false
    @State private var selectedRoomForMenu: RoomModel? = nil
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        VStack(spacing: UIConstants.Layout.zeroSpacing) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(.backLong)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: BlockedUserScreen.backIconSize,
                            height: BlockedUserScreen.backIconSize
                        )
                        .padding(.horizontal, BlockedUserScreen.backIconHPadding)
                        .padding(.vertical, BlockedUserScreen.backIconVPadding)
                }
                VStack(alignment: .leading, spacing: UIConstants.Layout.tightSpacing) {
                    Text(Constants.blockedUser.localized)
                        .font(Design.Font.blockedNavTitle)
                        .foregroundColor(Design.Color.white)
                }
                .padding(.leading, UIConstants.Layout.tightSpacing)

                Spacer()
            }
            .padding(.top, BlockedUserScreen.navTopPadding)
            .background(Design.Color.navBackground)

            roomList
        }
        .background(Design.Color.navBackground)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .ignoresSafeArea()
        .overlay {
            if showUnBlock {
                UnblockConfirmationView(
                    userName: selectedRoomForMenu?.name ?? "",
                    onUnblock: {
                        showUnBlock = false
                        guard let room = selectedRoomForMenu,
                              let user = room.opponent
                        else { return }
                        roomViewModel.unbanUser(from: room, user: user) { success in
                            if success {
                                if selectedRoomForMenu?.isBlocked == true {
                                    roomViewModel.toggeleBlocked(for: room)
                                }
                                selectedRoomForMenu?.isBlocked = false
                                if let roomIndex = roomViewModel.blockedRooms.firstIndex(where: { $0.id == room.id }) {
                                    roomViewModel.blockedRooms.remove(at: roomIndex)
                                }
                                print("User unbanned successfully")
                            }
                        }
                    },
                    onCancel: { showUnBlock = false }
                )
            }
        }
        .onAppear() {
            roomViewModel.loadRooms()
        }
    }
    
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }

    var roomList: some View {
        ScrollView(showsIndicators: false) {
            let blockedRooms = roomViewModel.blockedRooms

            VStack(spacing: UIConstants.Layout.zeroSpacing) {
                if blockedRooms.isEmpty {
                    Text(Constants.noBlockedRooms.localized)
                        .font(Design.Font.blockedEmptyState)
                        .foregroundColor(Design.Color.white.opacity(UIConstants.Opacity.medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, (UIScreen.main.bounds.height / 2)
                                - BlockedUserScreen.emptyStateTopPaddingOffset)
                } else {
                    ForEach(blockedRooms) { room in
                        BlockedUserRowView(room: room) {
                            selectedRoomForMenu = room
                            showUnBlock = true
                        }
                    }
                }
            }
            .padding(.top, BlockedUserScreen.listTopPadding)
            .padding(.bottom, BlockedUserScreen.listBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Design.Color.navBackground)
    }

    struct BlockedUserRowView: View {

        let room: RoomModel
        var onRemove: () -> Void

        @State private var downloadedImage: UIImage?
        @State private var downloadProgress: Double = 0.0

        var body: some View {
            HStack(spacing: BlockedUserScreen.rowSpacing) {

                // Profile Image
                if let image = downloadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: BlockedUserScreen.avatarSize,
                            height: BlockedUserScreen.avatarSize
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Design.Color.white,
                            lineWidth: BlockedUserScreen.avatarStrokeWidth))
                } else {
                    Circle()
                        .fill(Design.Color.avatarFallbackFill)
                        .frame(
                            width: BlockedUserScreen.avatarFallbackSize,
                            height: BlockedUserScreen.avatarFallbackSize
                        )
                        .overlay(
                            Text(room.name.prefix(1).uppercased())
                                .font(Design.Font.blockedInitials)
                                .foregroundColor(Design.Color.white)
                        )
                }

                // Name + Phone
                VStack(alignment: .leading, spacing: UIConstants.Layout.tightSpacing) {

                    Text(room.name)
                        .font(Design.Font.blockedUserName)
                        .foregroundColor(Design.Color.white)

                    if let phoneNumber = room.opponent?.phoneNumber {
                        Text(phoneNumber)
                            .font(Design.Font.blockedUserPhone)
                            .foregroundColor(Design.Color.white.opacity(UIConstants.Opacity.medium))
                    }
                }

                Spacer()

                Button(action: onRemove) {
                    Text(Constants.removeButton.localized)
                        .font(Design.Font.blockedRemoveButton)
                        .foregroundColor(Design.Color.blockedRemoveRed)
                        .padding(.horizontal, BlockedUserScreen.removeButtonHPadding)
                        .padding(.vertical, BlockedUserScreen.removeButtonVPadding)
                        .background(Color(Design.Color.darkgrayColor))
                }
            }
            .padding(.horizontal, BlockedUserScreen.rowHPadding)
            .padding(.vertical, BlockedUserScreen.rowVPadding)
            .background(Design.Color.navBackground)
            .onAppear {
                loadAvatar()
            }
        }

        private func loadAvatar() {

            guard let httpUrl = room.opponent?.avatarURL,
                  !httpUrl.isEmpty else { return }

            MediaCacheManager.shared.getMedia(
                url: httpUrl,
                type: .image,
                progressHandler: { progress in
                    downloadProgress = progress
                },
                completion: { result in

                    switch result {

                    case .success(let pathString):

                        let fileURL: URL =
                        pathString.hasPrefix("file://")
                        ? (URL(string: pathString) ?? URL(fileURLWithPath: pathString))
                        : URL(fileURLWithPath: pathString)

                        DispatchQueue.global(qos: .userInitiated).async {

                            if let img = UIImage(contentsOfFile: fileURL.path) {
                                DispatchQueue.main.async {
                                    downloadedImage = img
                                }
                            }

                        }

                    case .failure(let error):
                        print("Image error:", error)
                    }
                }
            )
        }
    }
}
