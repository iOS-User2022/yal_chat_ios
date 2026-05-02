//
//  ChatSettingsView.swift
//  YAL
//
//  Created by Hari krishna on 17/02/26.
//

import SwiftUI

struct ChatSettingsView: View {
    @StateObject private var viewModel: NotificationPreferencesViewModel
    @Environment(\.dismiss) var dismiss
    
    init() {
        let viewModel = DIContainer.shared.container.resolve(NotificationPreferencesViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Dark Background
            Color(hex: "0A171F")
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavigationBar()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Notification for chats section
                        notificationChatsSection()
                        
                        // Gradient Divider
                        gradientDivider
                        // Call section
                        callSection()
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.showSoundPicker) {
            SoundPickerView(
                selectedSound: viewModel.currentSoundPickerType == .messages ?
                    viewModel.currentMessagesSound : viewModel.currentGroupsSound,
                onSoundSelected: viewModel.selectSound
            )
        }
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
    private var gradientDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue,
                        Color.purple
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
    }
    
    // MARK: - Custom Navigation Bar
    private func customNavigationBar() -> some View {
        HStack(spacing: 16) {
            Button(action: {
                dismiss()
            }) {
                Image("back-long")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
            }
            
            Text("Chat Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                // More options action
                
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }
    
    // MARK: - Notification for chats Section
    private func notificationChatsSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                // Private chats
                darkCardRow(
                    icon: "ghost_chat",
                    title: "Ghost Chat",
                    subtitle: "",
                    isOn: true,
                    action: viewModel.toggleMessagesSoundEnabled
                )
                
                // Groups
                darkCardRow(
                    icon: "search_new",
                    title: "Search and summerisation",
                    subtitle: "",
                    isOn: viewModel.settingsManager.settings.groupsSoundEnabled,
                    action: viewModel.toggleGroupsSoundEnabled
                )
                
                // Stories
                darkCardRow(
                    icon: "smart_reply",
                    title: "Smart Replies",
                    subtitle: "",
                    isOn: true,
                    action: {}
                )
                
                // Reactions
                darkCardRow(
                    icon: "auto_correction",
                    title: "Auto correction",
                    subtitle: "",
                    isOn: viewModel.isMessagesReactionEnabled,
                    action: viewModel.toggleMessagesReactionNotifications
                )
            }
        }
    }
    
    // MARK: - Call Section
    private func callSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                
                sectionHeader("Storage")
                
                // MARK: - Chat Backup
                HStack(spacing: 12) {
                    Image("chat_backup")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    
                    Text("Chat Backup")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 25)
                
                
                // MARK: - Chat History
                NavigationLink(destination: ChatHistoryView()) {
                    HStack(spacing: 12) {
                        Image("chat_history")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("Chat History")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 18)
                }
            }
        }
    }
    private func navigableSettingRow<Destination: View>(
        _ title: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 16) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(.white)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(Design.Font.bold(14))
                
                Spacer()
            
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
    // MARK: - Notification Content Section
    private func notificationContentSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                sectionHeader("Notification Content")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    Text("Show")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    ForEach(Array(NotificationContentType.allCases.enumerated()), id: \.element) { index, type in
                        if index > 0 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                        }
                        
                        darkRadioRow(
                            title: type.displayName,
                            isSelected: viewModel.currentNotificationContentType == type,
                            action: {
                                Storage.save(type, for: .notificationContentType, type: .userDefaults)
                                viewModel.selectNotificationContentType(type)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Reminders Section
    private func remindersSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                sectionHeader("Reminders")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                
                darkToggleRowWithDescription(
                    title: "Reminders",
                    description: "Get occasional reminders about messages, calls, or status updates you haven't seen.",
                    isOn: viewModel.settingsManager.settings.remindersEnabled,
                    action: viewModel.toggleReminders
                )
            }
        }
    }
    
    // MARK: - Home Screen Notifications Section
    private func homeScreenNotificationsSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                sectionHeader("Home screen notifications")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                
                darkToggleRowWithDescription(
                    title: "Clear badge",
                    description: "Your home screen badge clears completely after every time you open the app.",
                    isOn: viewModel.settingsManager.settings.clearBadgeEnabled,
                    action: viewModel.toggleClearBadge
                )
            }
        }
    }
    
    // MARK: - In-app Notifications Section
    private func inAppNotificationsSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                sectionHeader("In-app notifications")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    ForEach(Array(InAppNotificationType.allCases.enumerated()), id: \.element) { index, type in
                        if index > 0 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                        }
                        
                        darkRadioRow(
                            title: type.displayName,
                            isSelected: viewModel.currentInAppNotificationType == type,
                            action: { viewModel.selectInAppNotificationType(type) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Show Preview Section
    private func showPreviewSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                darkToggleRow(
                    title: "Show preview",
                    isOn: viewModel.settingsManager.settings.showPreview,
                    action: viewModel.toggleShowPreview
                )
            }
        }
    }
    
    // MARK: - Helper Views
    private func darkCardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(hex: "0A171F"))
        .cornerRadius(12)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(Color.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5)
            .padding(.vertical, 0)
    }
    
    private func darkCardRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        // Create a local state that syncs with the passed value
        @State var toggleState = isOn
        
        return HStack(spacing: 12) {
            Image( icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    action()
                }
            ))
            .toggleStyle(GradientToggleStyle(
                gradient: LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 20)
    }
    
    private func darkToggleRow(
        title: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                        
            Spacer()
            
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                .onTapGesture {
                    action()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func darkToggleRowWithDescription(
        title: String,
        description: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                .onTapGesture {
                    action()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func darkRadioRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 0))
                    .foregroundColor(isSelected ? .blue : Color.white.opacity(0.3))
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
