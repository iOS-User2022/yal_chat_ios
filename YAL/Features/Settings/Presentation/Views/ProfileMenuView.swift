//
//  ProfileMenuView.swift
//  YAL
//
//  Created by Vishal Bhadade on 24/04/25.
//

import SwiftUI
import SDWebImageSwiftUI

enum ProfileRoute: Hashable {
    case blocked
    case threats
    case setting
    case notifications
    case lockChats
    case notificationsPrivateChat
    case notificationsGroupChat
    case notifiationStoryView
    case notifiationReactionView
}

final class AppSettings: ObservableObject {
    @Published var disableScreenshot: Bool = (Storage.get(for: .screenshotEnabled, type: .userDefaults, as: Bool.self) ?? false)
    @Published var muteNotification: Bool = false
    @Published var ghostChat: Bool = false
}

struct ProfileMenuView: View {
    @State private var showLanguageSheet = false
    @State private var showShareSheet = false
    @Environment(\.openURL) var openURL
    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject private var viewModel: ProfileMenuViewModel
    @State private var navPath = NavigationPath()

    @StateObject private var roomViewModel: RoomListViewModel
    @State private var showUnBlock = false
    @State private var selectedRoomForMenu: RoomModel? = nil
    @EnvironmentObject var appSettings: AppSettings

    let closeAction: () -> Void

    // MARK: - Single source-of-truth for every layout constant
    private enum Layout {
        static let headerBackground  = Color(hex: "#0A171F")
        static let contentBackground = Color(hex: "#202D35")
        static let rowLeading:  CGFloat = 24
        static let rowTrailing: CGFloat = 24
        static let rowVPad:     CGFloat = 18
        static let iconSize:    CGFloat = 20
        static let iconGap:     CGFloat = 16
        static let dividerInset: CGFloat = 24
    }

    init(closeAction: @escaping () -> Void) {
        self.closeAction = closeAction
        let viewModel = DIContainer.shared.container.resolve(ProfileMenuViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)

        let roomViewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _roomViewModel = StateObject(wrappedValue: roomViewModel)
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                //Two-tone background
                Layout.contentBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            topTogglesSection()
                            languageRow()
                            menuDivider()
                            middleSection()
                            menuDivider()
                            inviteFriendsRow()
                        }
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 0)
                    footerSection()
                }

                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: ["Check out YAL.ai — private, secure messaging.\nDownload now: https://apps.apple.com/app/id123456789"])
                }
                .navigationDestination(for: ProfileRoute.self) { route in
                    switch route {
                    case .blocked:      PrivacySecurityView()
                    case .threats:      destinationScreen(title: "Compromised Threats")
                    case .setting:      SettingsView(navPath: $navPath)
                    case .notifications: NotificationPreferencesView(navPath: $navPath)
                    case .lockChats:    ManageLockedChatsView(navPath: $navPath)
                    case .notificationsPrivateChat: PrivateChatNotificationView()
                    case .notificationsGroupChat: GroupChatNotificationView()
                    case .notifiationStoryView: NotificationStoryView()
                    case .notifiationReactionView : NotificationReactionsView()
                        
                    }
                }
                .onAppear { viewModel.loadProfile() }

                // Language picker overlay
                if showLanguageSheet {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showLanguageSheet = false } }

                    LanguagePickerView(isPresented: $showLanguageSheet)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Reusable divider (matches design reference blue tint)
    @ViewBuilder
    private func menuDivider() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#0C7BFF").opacity(1),
                        Color(hex: "#A72CFF").opacity(1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, Layout.dividerInset)
    }

    // MARK: - Header Section
    @ViewBuilder
    private func headerSection() -> some View {
        VStack(spacing: 0) {
            Layout.headerBackground
                .frame(height: safeAreaTop())

            HStack(spacing: Layout.iconGap) {
                // Avatar
                Group {
                    if let url = viewModel.imageURL {
                        WebImage(url: url, options: [.retryFailed, .continueInBackground])
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image("profile-icon")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))

                // Name + phone
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(viewModel.phone)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.horizontal, Layout.rowLeading)
            .padding(.vertical, 20)

        }
        .background(Layout.headerBackground)
    }

    // MARK: - Top Toggles Section
    @ViewBuilder
    private func topTogglesSection() -> some View {
        VStack(spacing: 0) {
            toggleRow(icon: "volume-cross",  label: "Mute Notification",  binding: $appSettings.muteNotification)
            toggleRow(icon: "camera-slash",  label: "Block screenshot",   binding: $appSettings.disableScreenshot)
            toggleRow(icon: "lock _icon", label: "Ghost Chat",         binding: $appSettings.ghostChat)
        }
    }

    @ViewBuilder
    private func toggleRow(icon: String, label: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: Layout.iconGap) {
            Image(icon)
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: Layout.iconSize, height: Layout.iconSize)

            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: binding)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#4A6FA5")))
                .labelsHidden()
                .scaleEffect(0.85)
        }
        .padding(.horizontal, Layout.rowLeading)
        .padding(.vertical, Layout.rowVPad)
    }
    // MARK: - Language Row
    @ViewBuilder
    private func languageRow() -> some View {
        Button(action: { showLanguageSheet.toggle() }) {
            HStack(spacing: Layout.iconGap) {
                Image("language_text")
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Language")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white)

                    Text("English")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image("arrow-right")
                    .renderingMode(.template)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, Layout.rowLeading)
            .padding(.vertical, Layout.rowVPad)
        }
    }

    // MARK: - Middle Section
    @ViewBuilder
    private func middleSection() -> some View {
        VStack(spacing: 0) {
            darkMenuRow(icon: "block_msg", title: "Blocked Messages",    action: { navPath.append(ProfileRoute.blocked) })
            darkMenuRow(icon: "thread",    title: "Compromised Threats", action: { navPath.append(ProfileRoute.threats) })
            darkMenuRow(icon: "setting",   title: "Settings",            action: { navPath.append(ProfileRoute.setting) })
        }
    }

    // MARK: - Invite Friends Row
    @ViewBuilder
    private func inviteFriendsRow() -> some View {
        Button(action: { showShareSheet.toggle() }) {
            HStack(spacing: Layout.iconGap) {
                Image("user-add")
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)

                Text("Invite Friends")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, Layout.rowLeading)
            .padding(.vertical, Layout.rowVPad)
        }
    }

    // MARK: - Dark Menu Row (navigation items)
    private func darkMenuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Layout.iconGap) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, Layout.rowLeading)
            .padding(.vertical, Layout.rowVPad)
        }
    }

    // MARK: - Footer
    @ViewBuilder
    private func footerSection() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    .white.opacity(1)
                )
                .frame(maxWidth: .infinity)

                .frame(height: 1)
            Text("YAL.ai never send your personal information to cloud, Your data stays on your device.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
        }
        .background(Layout.contentBackground)
    }

    // MARK: - Safe area helper
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }

    // MARK: - Destination screen (Blocked / Threats)
    private func destinationScreen(title: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { navPath.removeLast() }) {
                    Image("back-long")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.leading, 4)

                Spacer()
            }
            .padding(.top, safeAreaTop())
            .background(Layout.contentBackground)

            roomList
        }
        .background(Layout.contentBackground)
        .navigationBarBackButtonHidden(true)
        .overlay {
            if showUnBlock {
                UnblockConfirmationView(
                    userName: selectedRoomForMenu?.name ?? "",
                    onUnblock: {
                        showUnBlock = false
                        guard let room = selectedRoomForMenu,
                              let user = room.opponent else { return }
                        roomViewModel.unbanUser(from: room, user: user) { success in
                            if success {
                                if selectedRoomForMenu?.isBlocked == true {
                                    roomViewModel.toggeleBlocked(for: room)
                                }
                                selectedRoomForMenu?.isBlocked = false
                                if let idx = $roomViewModel.blockedRooms.firstIndex(where: { $0.id == room.id }) {
                                    roomViewModel.blockedRooms.remove(at: idx)
                                }
                            }
                        }
                    },
                    onCancel: { showUnBlock = false }
                )
            }
        }
        .onAppear { roomViewModel.loadRooms() }
    }

    var roomList: some View {
        ScrollView(showsIndicators: false) {
            let blockedRooms = roomViewModel.blockedRooms

            VStack(spacing: 24) {
                if blockedRooms.isEmpty {
                    Text("No blocked rooms")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, (UIScreen.main.bounds.height / 2) - 120)
                } else {
                    ForEach(blockedRooms) { room in
                        roomButton(for: room)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Layout.contentBackground)
    }

    func roomButton(for room: RoomModel) -> some View {
        GeometryReader { _ in
            ConversationView(roomModel: room, typingIndicator: "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .frame(height: 48)
        .onLongPressGesture {
            selectedRoomForMenu = room
            showUnBlock = true
        }
    }

    private func openAppNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
