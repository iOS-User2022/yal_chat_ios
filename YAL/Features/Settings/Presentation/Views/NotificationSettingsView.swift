//
//  NotificationPreferencesView.swift
//  YAL
//
//  Created by Sheetal Jha on 09/10/25.
//

import SwiftUI

struct NotificationPreferencesView: View {
    @StateObject private var viewModel: NotificationPreferencesViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var navPath: NavigationPath

    init(navPath: Binding<NavigationPath>) {
        let viewModel = DIContainer.shared.container.resolve(NotificationPreferencesViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
        self._navPath = navPath

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
        .navigationDestination(for: NotificationRoute.self) { route in
            switch route {
            case .privateChats:
                PrivateChatNotificationView()
            case .groups:
                GroupChatNotificationView()
            case .stories:
                NotificationStoryView()
            case .reactions:
                NotificationReactionsView()
            }
        }
        
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
            
            Text("Notifications and Sounds")
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
                sectionHeader("Notification for chats")
                
                darkCardRow(
                    icon: "private_chat",
                    title: "Private chats",
                    subtitle: "Preview, Sounds",
                    isOn: viewModel.settingsManager.settings.messagesSoundEnabled,
                    action: viewModel.toggleMessagesSoundEnabled,
                    onNavigate: {
                                navPath.append(ProfileRoute.notificationsPrivateChat)  // uses root stack
                            }
                )
                
                darkCardRow(
                    icon: "group_user",
                    title: "Groups",
                    subtitle: "Preview, Sounds",
                    isOn: viewModel.settingsManager.settings.groupsSoundEnabled,
                    action: viewModel.toggleGroupsSoundEnabled,
                    onNavigate: { navPath.append(ProfileRoute.notificationsGroupChat) }
                )
                
                darkCardRow(
                    icon: "story",
                    title: "Stories",
                    subtitle: "Preview, Sounds",
                    isOn: viewModel.settingsManager.settings.storiesSoundEnabled,
                    action: viewModel.toggleStoreisSoundEnabled,
                    onNavigate: { navPath.append(ProfileRoute.notifiationStoryView) }
                )
                
                darkCardRow(
                    icon: "reactions",
                    title: "Reactions",
                    subtitle: "Preview, Sounds",
                    isOn: viewModel.settingsManager.settings.reactionsSoundEnabled,
                    action: viewModel.toggleReactionsSoundEnabled,
                    onNavigate: { navPath.append(ProfileRoute.notifiationReactionView) }
                )
            }
        }
    }
    // MARK: - Call Section
    private func callSection() -> some View {
        darkCardContainer {
            VStack(spacing: 0) {
                sectionHeader("Call")
                
                // Vibrate
                darkCardRow(
                    icon: "vibrate",
                    title: "Vibrate",
                    subtitle: "Default (system)",
                    isOn: true,
                    action: {}
                )
                
                // Ringtone
                darkCardRow(
                    icon: "ringtone",
                    title: "Ringtone",
                    subtitle: "Default (system)",
                    isOn: true,
                    action: {}
                )
            }
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
            .foregroundColor(Color(hex: "#F7F7F7"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5)
            .padding(.vertical, 0)
    }
    
    private func darkCardRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Bool,
        action: @escaping () -> Void,
        onNavigate: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if newValue == false {
                        action()
                        onNavigate?()
                    } else {
                        action()
                    }
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
        .padding(.vertical, 14)
    }
    
    private func darkToggleRow(
        title: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .regular))
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
                    .font(.system(size: 22))
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

// MARK: - Sound Picker View
struct SoundPickerView: View {
    let selectedSound: NotificationSoundType
    let onSoundSelected: (NotificationSoundType) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1C1C1E")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ForEach(NotificationSoundType.allCases, id: \.self) { sound in
                        Button(action: {
                            onSoundSelected(sound)
                        }) {
                            HStack {
                                Text(sound.displayName)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if selectedSound == sound {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        
                        if sound != NotificationSoundType.allCases.last {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Notification Sound")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct GradientToggleStyle: ToggleStyle {
    var gradient: LinearGradient
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? gradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 36, height: 20)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(.spring(response: 0.3), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
