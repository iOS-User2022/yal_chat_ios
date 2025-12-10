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
}

final class AppSettings: ObservableObject {
    @Published var disableScreenshot: Bool = (Storage.get(for: .screenshotEnabled, type: .userDefaults, as: Bool.self) ?? false)
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

    init(closeAction: @escaping () -> Void) {
        self.closeAction = closeAction
        let viewModel = DIContainer.shared.container.resolve(ProfileMenuViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        
        let roomViewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _roomViewModel = StateObject(wrappedValue: roomViewModel)
    }
    
    var toggleSection: some View {
        HStack {
            Text("Disable screenshots for privacy")
                .font(Design.Font.bold(14))
                .foregroundColor(Design.Color.headingText)
            
            Spacer()
            
            Toggle(isOn: $appSettings.disableScreenshot) {
                Text("")
            }
            .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
            .labelsHidden()
            .frame(width: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                VStack(spacing: 0) {
                    headerSection()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            sectionBox {
                                SettingRow(label: "Language", value: "English", icon: "language") {
                                    showLanguageSheet.toggle()
                                }
                                SettingRow(label: "Mute Notification", icon: "mute") {
                                    openAppNotificationSettings()
                                }
                                
                                SettingRow(label: "Manage Locked Chats", icon: "lockBlack") {
                                    navPath.append(ProfileRoute.lockChats)
                                }
                                
                                toggleSection
                            }
                            
                            sectionBox {
                                SettingRow(label: "Blocked Messages", icon: "blocked") {
                                    navPath.append(ProfileRoute.blocked)
                                }
                                SettingRow(label: "Compromised Threats", icon: "comparison") {
                                    navPath.append(ProfileRoute.threats)
                                }
                                SettingRow(label: "Settings", icon: "settings") {
                                    navPath.append(ProfileRoute.setting)
                                }
                            }
                            
                            sectionBox {
                                SettingRow(label: "Invite Friends", icon: "invite") {
                                    showShareSheet.toggle()
                                }
                            }
                        }
                        .background(Design.Color.appGradient.opacity(0.12))
                        .padding(.horizontal, 0)
                        .padding(.top, 12)
                    }
                    .background(Color.white)
                    
                    footerSection()
                    Spacer().frame(height: 20)
                }
                .ignoresSafeArea(.all)
                .background(Color.white)
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: ["Check out YAL.ai — private, secure messaging.\nDownload now: https://apps.apple.com/app/id123456789"])
                }
                .navigationDestination(for: ProfileRoute.self) { route in
                    switch route {
                    case .blocked:
                        destinationScreen(title: "Blocked Messages")
                    case .threats:
                        destinationScreen(title: "Compromised Threats")
                    case .setting:
                        SettingsView(navPath: $navPath)
                    case .notifications:
                        NotificationPreferencesView()
                    case .lockChats:
                        ManageLockedChatsView(navPath: $navPath)
                    }
                }
                .onAppear() {
                    viewModel.loadProfile()
                }
                
                // — Overlay picker when needed —
                if showLanguageSheet {
                    // 1) Semi-transparent backdrop
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showLanguageSheet = false }
                        }
                    
                    // 2) The floating card
                    LanguagePickerView(isPresented: $showLanguageSheet)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                //Spacer().frame(height: 52)
                Spacer().frame(height: UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }
                               .first?.safeAreaInsets.top ?? 0 + 16)
            
                if let url = viewModel.imageURL {
                    WebImage(url: url, options: [.retryFailed, .continueInBackground])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else {
                    Image("profile-icon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                
                Spacer().frame(height: 12)
                
                Text(viewModel.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Spacer().frame(height: 8)
                
                Text(viewModel.phone)
                    .foregroundColor(Design.Color.white)
                    .font(Design.Font.bold(14))
                
                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .background(Design.Color.appGradient)
            .ignoresSafeArea(.all, edges: .top)
            
            Button(action: {
                withAnimation {
                    closeAction()
                }
            }) {
                Image("arrow-left-white")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .padding(.top, 52)
            .padding(.leading, 20)
        }
    }

    // MARK: - Footer
    @ViewBuilder
    private func footerSection() -> some View {
        VStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Design.Color.backgroundMuted)

            HStack(spacing: 12) {
                Image("yal-shield")
                    .resizable()
                    .frame(width: 52, height: 52)

                Text("YAL.ai never send your personal information to cloud, Your data stays on your device.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.white)
    }

    // MARK: - Section Box
    private func sectionBox<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .background(Design.Color.white)
    }

    // MARK: - Setting Row
    private func SettingRow(label: String, value: String? = nil, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(Design.Font.bold(14))
                        .foregroundColor(Design.Color.headingText)

                    if let value = value {
                        Text(value)
                            .font(Design.Font.regular(12))
                            .foregroundColor(Design.Color.tertiaryText)
                    }
                }

                Spacer()

                Image("arrow-right")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white)
        }
    }
    
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }

    // MARK: - Destination screen (for Blocked, Threats)
    private func destinationScreen(title: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    navPath.removeLast()
                }) {
                    Image("back-long")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked Messages")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.leading, 4)
                
                Spacer()
            }
            .padding(.top, safeAreaTop())
            roomList
        }
        .navigationBarBackButtonHidden(true)
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
                                if let roomIndex = $roomViewModel.blockedRooms.firstIndex(where: { $0.id == room.id }) {
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
        .onAppear(){
            roomViewModel.loadRooms()
        }
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
                        .padding(.top, (UIScreen.main.bounds.height / 2) - (120))
                } else {
                    ForEach(blockedRooms) { room in
                        roomButton(for: room)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure it occupies available space
        .background(Design.Color.tabHighlight.opacity(0.12))
    }

    func roomButton(for room: RoomModel) -> some View {
        GeometryReader { geo in
            ConversationView(roomModel: room, typingIndicator: "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .frame(height: 48)
        .opacity(1.0)
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
