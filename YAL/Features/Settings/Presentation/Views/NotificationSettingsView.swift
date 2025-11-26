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
    
    init() {
        let viewModel = DIContainer.shared.container.resolve(NotificationPreferencesViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.white
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavigationBar()
                
                Spacer().frame(height: 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Messages Section
                        messagesSection()
                        
                        // Groups Section
                        groupsSection()
                        
                        // Notification Content Section
                        notificationContentSection()
                        
                        // Reminders Section
                        remindersSection()
                        
                        // Home Screen Notifications Section
                        homeScreenNotificationsSection()
                        
                        // In-app Notifications Section
                        inAppNotificationsSection()
                        
                        // Show Preview Section
                        showPreviewSection()
                        
                        Spacer().frame(height: 40)
                    }
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
    
    // MARK: - Custom Navigation Bar
    private func customNavigationBar() -> some View {
        HStack(spacing: 20) {
            Button(action: {
                dismiss()
            }) {
                Image("back-long")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            
            Spacer().frame(width: 20)
            
            Text("Notifications")
                .font(Design.Font.heavy(16))
                .foregroundColor(Design.Color.headingText)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
    }
    
    // MARK: - Messages Section
    private func messagesSection() -> some View {
        sectionContainer {
            VStack(spacing: 0) {
                sectionHeader("Messages")
                    .padding(.top, 4)
                
                toggleRow(
                    title: "Sound Notifications",
                    isOn: viewModel.settingsManager.settings.messagesSoundEnabled,
                    action: viewModel.toggleMessagesSoundEnabled
                )
                
                navigationRow(
                    title: "Sound",
                    action: viewModel.showMessagesSoundPicker
                )
                
                toggleRow(
                    title: "Show reaction notifications",
                    isOn: viewModel.isMessagesReactionEnabled,
                    action: viewModel.toggleMessagesReactionNotifications,
                    isEnabled: viewModel.settingsManager.settings.messagesSoundEnabled
                )
            }
        }
    }
    
    // MARK: - Groups Section
    private func groupsSection() -> some View {
        sectionContainer {
            VStack(spacing: 0) {
                sectionHeader("Groups")
                    .padding(.top, 4)
                
                toggleRow(
                    title: "Sound Notifications",
                    isOn: viewModel.settingsManager.settings.groupsSoundEnabled,
                    action: viewModel.toggleGroupsSoundEnabled
                )
                
                navigationRow(
                    title: "Sound",
                    action: viewModel.showGroupsSoundPicker
                )
                
                toggleRow(
                    title: "Show reaction notifications",
                    isOn: viewModel.isGroupsReactionEnabled,
                    action: viewModel.toggleGroupsReactionNotifications,
                    isEnabled: viewModel.settingsManager.settings.groupsSoundEnabled
                )
            }
        }
    }
    
    // MARK: - Notification Content Section
    private func notificationContentSection() -> some View {
        sectionContainer {
            VStack(spacing: 0) {
                sectionHeader("Notification Content")
                    .padding(.top, 4)
                
                VStack(spacing: 0) {
                    Text("Show")
                        .font(Design.Font.medium(14))
                        .foregroundColor(Design.Color.headingText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    ForEach(NotificationContentType.allCases, id: \.self) { type in
                        radioRow(
                            title: type.displayName,
                            isSelected: viewModel.currentNotificationContentType == type,
                            action: {
                                print("Selected content type:", type)
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
        sectionContainer {
            VStack(spacing: 0) {
                toggleRowWithDescription(
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
        sectionContainer {
            VStack(spacing: 0) {
                sectionHeader("Home screen notifications")
                    .padding(.top, 4)
                
                toggleRowWithDescription(
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
        sectionContainer {
            VStack(spacing: 0) {
                sectionHeader("In-app notifications")
                    .padding(.top, 4)
                
                ForEach(InAppNotificationType.allCases, id: \.self) { type in
                    radioRow(
                        title: type.displayName,
                        isSelected: viewModel.currentInAppNotificationType == type,
                        action: { viewModel.selectInAppNotificationType(type) }
                    )
                }
            }
        }
    }
    
    // MARK: - Show Preview Section
    private func showPreviewSection() -> some View {
        sectionContainer {
            VStack(spacing: 0) {
                toggleRow(
                    title: "Show preview",
                    isOn: viewModel.settingsManager.settings.showPreview,
                    action: viewModel.toggleShowPreview,
                    font: Design.Font.semiBold(16)
                )
            }
        }
    }
    
    // MARK: - Helper Views
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Design.Color.tabHighlight.opacity(0.12))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Design.Font.semiBold(14))
            .foregroundColor(Design.Color.headingText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }
    
    private func toggleRow(
        title: String,
        isOn: Bool,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        font: Font = Design.Font.regular(16)
    ) -> some View {
        HStack {
            Text(title)
                .font(font)
                .foregroundColor(Design.Color.headingText)
                        
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
                .disabled(!isEnabled)
                .onTapGesture {
                    if isEnabled {
                        action()
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func toggleRowWithDescription(
        title: String,
        description: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.headingText)
                    .padding(.top, 4)
                
                Text(description)
                    .font(Design.Font.regular(10))
                    .foregroundColor(Color(hex: "828188"))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
                .onTapGesture {
                    action()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func navigationRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Design.Font.regular(16))
                    .foregroundColor(Design.Color.headingText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Design.Color.grayText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    private func radioRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Design.Color.blue : Design.Color.grayText)
                
                Text(title)
                    .font(Design.Font.regular(16))
                    .foregroundColor(Design.Color.headingText)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
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
            VStack(spacing: 0) {
                ForEach(NotificationSoundType.allCases, id: \.self) { sound in
                    Button(action: {
                        onSoundSelected(sound)
                    }) {
                        HStack {
                            Text(sound.displayName)
                                .font(Design.Font.regular(16))
                                .foregroundColor(Design.Color.headingText)
                            
                            Spacer()
                            
                            if selectedSound == sound {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Design.Color.blue)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Notification Sound")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
