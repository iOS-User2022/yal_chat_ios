//
//  CallLogView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI
import ContactsUI
import RealityKit

struct CallLogView: View {
    @StateObject private var viewModel = CallLogViewModel()
    @StateObject private var callStateManager = CallStateManager.shared
    @State private var selectedFilter: CallFilter = .all
    @State private var showShareSheet = false
    @State private var showContactPicker = false
    @State private var shareItems: [Any] = [Constants.shareItemStr.rawValue]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(Constants.ellipseImage.rawValue)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: UIConstants.Layout.zeroSpacing) {
                    searchBar
                    tabFilters

                    if (CallManager.shared.callState == .ongoing ||
                        CallManager.shared.callState == .outgoing ||
                        CallManager.shared.callState == .incoming)
                        && CallManager.shared.currentRoomModel != nil {
                        OngoingCallWidget(
                            participants: CallManager.shared.currentRoomModel?.participants ?? [],
                            callType: CallManager.shared.isVideoCall ? (Constants.chatVideo).rawValue : (Constants.chatVoice).rawValue,
                            callState: CallManager.shared.callState,
                            onJoinCall: {
                                if let rm = CallManager.shared.currentRoomModel {
                                    CallManager.shared.presentCall(for: rm)
                                    CallManager.shared.callState = .ongoing
                                }
                            }
                        )
                        .padding(.horizontal, UIConstants.Layout.Radius.small)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(UIConstants.Layout.deleteButtonBorderWidth)
                    }

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(UIConstants.Layout.scaleEffectSpacing)
                        Spacer()
                    } else if viewModel.filteredCallLogs.isEmpty {
                        emptyStateView
                    } else {
                        callLogList
                    }
                }
            }
            .background(Design.Color.backgroundColor)
            .overlay(
                floatingButton
                    .position(
                        x: geometry.size.width - UIConstants.Layout.screenPadding - UIConstants.Layout.floatingButtonX,
                        y: geometry.size.height - UIConstants.Layout.ExtrainternalPadding - UIConstants.Layout.floatingButtonX
                    )
            )
            // Share Sheet
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            // Contact Picker as background (CNContactPickerViewController manages its own presentation)
            .background(
                ContactPickerView(isPresented: $showContactPicker) { selectedContact in
                    viewModel.startCallFromContact(selectedContact)
                }
            )
        }
    }

    // MARK: - Call Log List
    private var callLogList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: UIConstants.Layout.zeroSpacing) {
                ForEach(groupedCallLogs, id: \.date) { section in
                    if !section.title.isEmpty {
                        HStack {
                            Text(section.title)
                                .font(.system(size: UIConstants.Layout.Radius.small, weight: .regular))
                                .foregroundColor(Color(hex: UIConstants.Layout.EditProfile.callLogForegroundColor))
                                .padding(.horizontal, UIConstants.Layout.screenPadding)
                                .padding(.top, UIConstants.Layout.elementPadding)
                                .padding(.bottom, UIConstants.Layout.Radius.small)
                            Spacer()
                        }
                    }

                    ForEach(section.callLogs) { callLog in
                        CallLogRowView(
                            callLog: callLog,
                            onVideoCallTap: {
                                viewModel.startVideoCall(to: callLog)
                            },
                            onAudioCallTap: {
                                viewModel.makeCall(to: callLog)
                            }
                        )

                        if callLog.id != section.callLogs.last?.id {
                            Divider()
                                .padding(.leading,UIConstants.Layout.paddingSpace)
                        }
                    }

                    if section.date != groupedCallLogs.last?.date {
                        Divider()
                            .padding(.vertical, UIConstants.Layout.Radius.small)
                    }
                }
            }
            .padding(.top, UIConstants.Layout.screenPadding)
            .padding(.bottom, UIConstants.Layout.bottomSpace)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: UIConstants.Layout.zeroSpacing) {
            Spacer()
                .frame(height: UIConstants.Layout.backButtonPadding)

            Image(Constants.group34Image.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: UIConstants.Layout.EditProfile.Button.width, height:  UIConstants.Layout.EditProfile.Button.width)
                .padding(.bottom, UIConstants.Layout.verticalPadding)

            VStack(spacing: UIConstants.Layout.zeroSpacing) {
                Text(Constants.callLogEmpty.rawValue)
                    .font(.system(size: UIConstants.Layout.elementPadding, weight: .regular))
                    .foregroundColor(.white)

                Text(Constants.startNewCall.rawValue)
                    .font(.system(size: UIConstants.Layout.elementPadding, weight: .regular))
                    .foregroundColor(.white)
            }
            .padding(.bottom, UIConstants.Layout.wideScreenPadding)

            VStack(spacing: UIConstants.Layout.screenPadding) {
                // Call a Contact Button
                Button(action: {
                    openPhoneDialer()
                }) {
                    Text(Constants.callContact.rawValue)
                        .font(.system(size: UIConstants.Layout.menuItemIconSpacing, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: UIConstants.Layout.ProfileView.AboutSection.editorHeight)
                        .frame(height: UIConstants.Layout.backButtonPadding)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red:UIConstants.Layout.color1, green: UIConstants.Layout.color2, blue:UIConstants.Opacity.highest),
                                    Color(red: UIConstants.Layout.ProfileView.AboutSection.editorOpacity, green: UIConstants.Layout.ProfileView.ProfileField.emptyOpacity, blue:UIConstants.Layout.color3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(ChatLayout.attachmentSpacing)
                }

                // Invite a Friend Button
                Button(action: {
                    shareApp()
                }) {
                    Text(Constants.inviteFriendCallLogView.rawValue)
                        .font(.system(size: UIConstants.Layout.menuItemIconSpacing, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: UIConstants.Layout.ProfileView.AboutSection.editorHeight)
                        .frame(height: UIConstants.Layout.backButtonPadding)
                        .overlay(
                            RoundedRectangle(cornerRadius: ChatLayout.attachmentSpacing)
                                .stroke(Color.white, lineWidth: UIConstants.Layout.deleteButtonBorderWidth)
                        )
                }
            }
            .padding(.horizontal, UIConstants.Layout.backButtonPadding)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // MARK: - Share App
    private func shareApp() {
        let shareText = Constants.shareItemStr.rawValue
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // Get the current top-most view controller and present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // Handle iPad popover (required or it crashes on iPad)
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: UIConstants.Layout.zeroSpacing,
                height: UIConstants.Layout.zeroSpacing
            )
            activityVC.popoverPresentationController?.permittedArrowDirections = []

            rootVC.present(activityVC, animated: true)
        }
    }
    // MARK: - Open Native Phone Dialer
    private func openPhoneDialer() {
        // Opens native iOS Phone app on keypad tab
        if let url = URL(string: Constants.tell.rawValue) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // Simulator doesn't support calls — handle gracefully
                print(Constants.deviceNotSupportPhoneCall.rawValue)
            }
        }
    }
    // MARK: - Grouped Call Logs
    private var groupedCallLogs: [CallLogSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.filteredCallLogs) { callLog in
            calendar.startOfDay(for: callLog.timestamp)
        }

        return grouped.map { date, callLogs in
            let title: String
            if calendar.isDateInToday(date) {
                title = Constants.today.rawValue
            } else if calendar.isDateInYesterday(date) {
                title = Constants.yesterday.rawValue
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                title = formatter.string(from: date)
            }

            return CallLogSection(
                date: date,
                title: title,
                callLogs: callLogs.sorted { $0.timestamp > $1.timestamp }
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Floating Button
    private var floatingButton: some View {
        Button(action: {
            showContactPicker = true
        }) {
            ZStack {
                CustomRoundedCornersShape(radius: ChatLayout.attachmentSpacing, roundedCorners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Design.Color.appGradient)
                    .frame(width: UIConstants.Layout.Height.tapTarget, height: UIConstants.Layout.Height.tapTarget)

                Image(UIConstants.Symbols.addWhite)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIConstants.Layout.screenPadding, height: UIConstants.Layout.screenPadding)
            }
        }
        .shadow(radius: UIConstants.Layout.verticalPadding)
    }
}

// MARK: - Search Bar & Tab Filters
private extension CallLogView {

    var searchBar: some View {
        SearchBarView(placeholder: Constants.searchNamesAndMore.rawValue, text: $viewModel.searchText)
            .padding(.horizontal, UIConstants.Layout.screenPadding)
            .padding(.top, ChatLayout.attachmentSpacing)
            .padding(.bottom, UIConstants.Layout.screenPadding)
    }

    var tabFilters: some View {
        TabFiltersView(filters: CallFilter.allCases, selectedFilter: $selectedFilter)
            .onChange(of: selectedFilter) { newFilter in
                viewModel.updateFilter(newFilter)
            }
    }
}

// MARK: - Call Log Section Model
struct CallLogSection {
    let date: Date
    let title: String
    let callLogs: [CallLogEntry]
}



// MARK: - Contact Picker
struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onContactSelected: (CNContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onContactSelected: onContactSelected)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        // Plain wrapper — CNContactPickerViewController is presented on top
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            // Only show contacts that have at least one phone number
            picker.predicateForEnablingContact = NSPredicate(format: Constants.phoneNumberCount.rawValue)
            uiViewController.present(picker, animated: true)
        }
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var isPresented: Bool
        var onContactSelected: (CNContact) -> Void

        init(isPresented: Binding<Bool>, onContactSelected: @escaping (CNContact) -> Void) {
            self._isPresented = isPresented
            self.onContactSelected = onContactSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactSelected(contact)
            isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            isPresented = false
        }
    }
}
