//
//  LockedChatView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 23/10/25.
//

import SwiftUI

struct LockedChatView: View {
    @Binding private var rooms: [RoomModel]
    @StateObject private var viewModel: RoomListViewModel
    @Binding var navPath: NavigationPath
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var unblockRooms: [RoomModel] = []

    init(rooms: Binding<[RoomModel]>, navPath: Binding<NavigationPath>) {
        self._rooms = rooms
        self._navPath = navPath
        let viewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    headerSection
                    roomList
                }
                .background(Design.Color.backgroundColor)
                floatingButton
                    .position(
                        x: geometry.size.width - UIConstants.Layout.screenPadding - UIConstants.Layout.floatingButtonX,
                        y: geometry.size.height - UIConstants.Layout.internalPadding - UIConstants.Layout.floatingButtonY
                    )
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .inactive {
                    handleAppWillEnterBackground()
                }
            }
        }.navigationBarBackButtonHidden(true)
    }
    
    private func handleAppWillEnterBackground() {
        DispatchQueue.main.async {
            if !navPath.isEmpty {
                navPath.removeLast()
            }
        }
    }
    
    var roomList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UIConstants.Layout.menuIconWidth) {
                ForEach(rooms) { room in
                    roomButton(for: room)
                }
            }
            .padding(.horizontal, UIConstants.Layout.screenPadding)
            .padding(.top, UIConstants.Layout.screenPadding)
            .padding(.bottom, UIConstants.Layout.screenPadding)
        }
        .frame(maxWidth: .infinity)
        .background(Design.Color.tabHighlight.opacity(UIConstants.Opacity.low))
    }
    
    func toggleUnblock(for room: RoomModel) {
        if unblockRooms.contains(room) {
            unblockRooms.removeAll { $0 == room }
        } else {
            unblockRooms.append(room)
        }
    }
    
    func roomButton(for room: RoomModel) -> some View {
        GeometryReader { geo in
            ConversationView(roomModel: room, typingIndicator: "")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedRoom = room
                    navPath.append(NavigationTarget.chat(room: room))
                }
                .onLongPressGesture {
                    toggleUnblock(for: room)
                }
        }
        .frame(height: UIConstants.Layout.Height.chatRowHeight)
        .opacity((unblockRooms.contains(where: { $0.id == room.id }) || unblockRooms.count == 0) ? UIConstants.Opacity.highest : UIConstants.Opacity.medium)
    }
    
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }
    
    var headerSection: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                VStack {
                    Button(action: {
                        navPath.removeLast()
                    }) {
                        Image(UIConstants.Symbols.backIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: UIConstants.Layout.screenPadding, height: UIConstants.Layout.screenPadding)
                            .padding(.horizontal, UIConstants.Layout.verticalPadding)
                            .padding(.vertical, UIConstants.Layout.verticalPadding)
                    }
                    .padding(.leading, UIConstants.Layout.verticalPadding)
                    .frame(width: UIConstants.Layout.Height.iconMedium, height: UIConstants.Layout.Height.iconMedium)
                }
                Text(Constants.lockedChats.localized)
                    .font(Design.Font.semiBold(UIConstants.Layout.elementPadding))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if unblockRooms.count > 0 {
                    Text(Constants.remove.localized)
                        .font(Design.Font.semiBold(UIConstants.Layout.Height.iconSmallest))
                        .frame(alignment: .leading)
                        .padding(.trailing, UIConstants.Layout.verticalPadding)
                        .onTapGesture {
                            unblockRooms.forEach{ room in
                                self.rooms.removeAll { $0.id == room.id }
                                viewModel.toggeleLocked(for: room)
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, safeAreaTop())
        .background(Color(Design.Color.darkgrayColor))
    }
    
    var floatingButton: some View {
        Button(action: {
            navPath.append(NavigationTarget.manageLockedChats)
        }) {
            ZStack {
                CustomRoundedCornersShape(radius: UIConstants.Layout.internalPadding, roundedCorners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Design.Color.appGradient)
                    .frame(width: UIConstants.Layout.Height.tapTarget, height: UIConstants.Layout.Height.tapTarget)
                
                Image(UIConstants.Symbols.callAdd)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIConstants.Layout.screenPadding, height: UIConstants.Layout.screenPadding)
            }
        }
        .shadow(radius: UIConstants.Layout.verticalPadding)
    }
}


struct ManageLockedChatsView: View {
    // MARK: - Stored Values
    @State private var isLockedChatsEnabled: Bool = Storage.get(for: .isLockedChatsEnabled, type: .userDefaults, as: Bool.self) ?? true
    @State private var selectedSecurityOption: LockSecurityOption? = {
        if let raw: String = Storage.get(for: .lockSecurityOption, type: .userDefaults, as: String.self) {
            return LockSecurityOption(rawValue: raw)
        }
        return .biometric
    }()
    @State private var showSetPinView = false

    @Binding var navPath: NavigationPath
    var onBack: () -> Void

    init(navPath: Binding<NavigationPath> = .constant(NavigationPath()), onBack: @escaping () -> Void = {}) {
        self._navPath = navPath
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView(showsIndicators: false) {
                VStack(spacing: UIConstants.Layout.internalPadding) {
                    enableToggleSection
                    
                    Group {
                        lockSecuritySection
                    }
                    .disabled(!isLockedChatsEnabled)
                    .opacity(isLockedChatsEnabled ? UIConstants.Opacity.highest : UIConstants.Opacity.medium)

                }
                .padding(.top, UIConstants.Layout.EditProfile.Field.labelSpacing)
            }

            Spacer()
        }
        .background(Design.Color.backgroundColor)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .sheet(isPresented: $showSetPinView) {
            SetPinView { pin in
                Storage.save(pin, for: .lockPin, type: .userDefaults)
            }
        }
        // MARK: - Persist Changes
        .onChange(of: isLockedChatsEnabled) { newValue in
            Storage.save(newValue, for: .isLockedChatsEnabled, type: .userDefaults)
        }
        .onChange(of: selectedSecurityOption) { newValue in
            Storage.save(newValue?.rawValue, for: .lockSecurityOption, type: .userDefaults)
        }
    }
}

// MARK: - Header
private extension ManageLockedChatsView {
    var headerSection: some View {
        HStack(spacing: UIConstants.Layout.EditProfile.Field.labelSpacing) {
            Button(action: {
                if !navPath.isEmpty {
                    navPath.removeLast()
                } else {
                    onBack()
                }
            }) {
                Image(UIConstants.Symbols.backIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UIConstants.Layout.screenPadding, height: UIConstants.Layout.screenPadding)
            }

            Text(Constants.manageLockedChats.localized)
                .font(Design.Font.semiBold(UIConstants.Layout.elementPadding))
                .foregroundColor(Design.Color.primaryTextColor)

            Spacer()
        }
        .padding(.horizontal, UIConstants.Layout.screenPadding)
        .padding(.top, safeAreaTop() + UIConstants.Layout.internalPadding)
        .padding(.bottom, UIConstants.Layout.EditProfile.Field.labelSpacing)
    }

    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }
}

// MARK: - Sections
private extension ManageLockedChatsView {
    var enableToggleSection: some View {
        HStack {
            Text(Constants.enableLockedChats.localized)
                .font(Design.Font.regular(15))
                .foregroundColor(Design.Color.primaryTextColor)

            Spacer()

            Toggle("", isOn: $isLockedChatsEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
        }
        .padding(.horizontal, UIConstants.Layout.screenPadding)
        .padding(.vertical, UIConstants.Layout.Height.iconSmallest)
        .background(Color.gray.opacity(UIConstants.Opacity.low))
    }

    var lockSecuritySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Constants.lockChatSecurity.localized)
                .font(Design.Font.semiBold(UIConstants.Layout.Height.iconSmallest))
                .foregroundColor(Design.Color.primaryTextColor)
                .padding(.horizontal, UIConstants.Layout.screenPadding)
                .padding(.vertical, UIConstants.Layout.internalPadding)

            ForEach(LockSecurityOption.allCases, id: \.self) { option in
                Button(action: {
                    selectedSecurityOption = option
                    if option == .pin {
                        showSetPinView = true
                    }
                }) {
                    HStack(spacing: UIConstants.Layout.verticalPadding) {
                        Image(systemName: selectedSecurityOption == option ?
                              UIConstants.Symbols.checkBoxCircleFilled :
                                UIConstants.Symbols.checkBoxCircle)
                            .foregroundColor(.white)
                            .font(.system(size: UIConstants.Layout.elementPadding, weight: .semibold))

                        Text(option.label)
                            .font(Design.Font.regular(UIConstants.Layout.Height.iconSmallest))
                            .foregroundColor(Design.Color.primaryTextColor)

                        Spacer()

                        if option == .pin {
                            Text(Constants.setPinTitle.localized)
                                .font(Design.Font.semiBold(UIConstants.Layout.Height.iconSmallest))
                                .foregroundColor(.white)
                                .underline(true, color: .white)
                        }
                    }
                    .padding(.horizontal, UIConstants.Layout.screenPadding)
                    .padding(.vertical, UIConstants.Layout.verticalPadding)
                }
            }
        }
        .background(Color.gray.opacity(UIConstants.Opacity.low))
    }
}


// MARK: - Enums
enum LockSecurityOption: String, CaseIterable {
    case biometric
    case faceID
    case pin
    
    var label: String {
        switch self {
        case .biometric:
            return Constants.biometricSystemDefault.localized
        case .faceID:
            return Constants.faceIdSystemDefault.localized
        case .pin:
            return Constants.pin.localized
        }
    }
}

//
//  SetPinView.swift
//  YAL
//
//  Created by Vishal Bhadade on 27/10/25.
//

import SwiftUI
import Combine

struct SetPinView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pinDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    
    var onSave: (String) -> Void
    var isConfirmMode: Bool = false

    private var isPinComplete: Bool {
        pinDigits.joined().count == UIConstants.pinDigits
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: UIConstants.Layout.spacing120)
                
                Text(isConfirmMode ? Constants.verifyPin.localized : Constants.setPinTitle.localized)
                    .font(Design.Font.bold(UIConstants.Layout.menuIconWidth))
                    .foregroundColor(Design.Color.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, UIConstants.Layout.sectionBottomPadding)
                
                subHeadingSection()
                Spacer().frame(height: UIConstants.Layout.menuIconWidth)
                
                // Reuse the same OTP-style input
                otpInputFields()
                
                Spacer().frame(height: UIConstants.Layout.Height.chatRowHeight)
                
                verifyButton()
                
                Spacer()
            }
            .padding(.horizontal, UIConstants.Layout.sectionBottomPadding)
            .background(Design.Color.backgroundColor)
            
            backButton()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private func subHeadingSection() -> some View {
        (
            Text(!isConfirmMode ? Constants.setPinDesc.localized :
                    Constants.verifyPinDesc.localized)
            .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
                .font(Design.Font.body)
        )
        .multilineTextAlignment(.center)
    }

    // MARK: - OTP Style Input
    @ViewBuilder
    private func otpInputFields() -> some View {
        ZStack {
            hiddenTextField()
            HStack(spacing: UIConstants.Layout.elementPadding) {
                ForEach(0..<UIConstants.pinDigits, id: \.self) { index in
                    otpBox(index: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedIndex = 0 }
        }
    }

    @ViewBuilder
    private func hiddenTextField() -> some View {
        TextField("", text: Binding(
            get: { pinDigits.joined() },
            set: { newValue in
                let cleaned = String(newValue.prefix(6))
                for (i, char) in cleaned.enumerated() {
                    if i < pinDigits.count {
                        pinDigits[i] = String(char)
                    }
                }
                for i in cleaned.count..<pinDigits.count {
                    pinDigits[i] = ""
                }
            }
        ))
        .keyboardType(.numberPad)
        .frame(width: UIConstants.Layout.deleteButtonBorderWidth,
               height: UIConstants.Layout.deleteButtonBorderWidth)
        .opacity(UIConstants.Opacity.lowest)
        .focused($focusedIndex, equals: 0)
    }

    @ViewBuilder
    private func otpBox(index: Int) -> some View {
        VStack(spacing: 2) {
            Spacer()
            Text(pinDigits[index])
                .font(Design.Font.regular(UIConstants.Layout.elementPadding))
                .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
            if pinDigits[index].isEmpty {
                Rectangle()
                    .frame(width: 11, height: UIConstants.Layout.deleteButtonBorderWidth)
                    .foregroundColor(Design.Color.primaryTextColor.opacity(UIConstants.Opacity.medium))
                    .padding(.horizontal, UIConstants.Layout.EditProfile.Field.labelSpacing)
                Spacer().frame(height: 3)
            }
        }
        .padding(7)
        .frame(width: 27, height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 0.5)
                .stroke(Design.Color.white,
                        lineWidth: UIConstants.Layout.deleteButtonBorderWidth)
        )
    }

    // MARK: - Verify/Save Button
    @ViewBuilder
    private func verifyButton() -> some View {
        Button(action: {
            if isPinComplete {
                onSave(pinDigits.joined())
                dismiss()
            }
        }) {
            HStack(spacing: UIConstants.Layout.internalPadding) {
                Spacer()
                Text(isConfirmMode ? Constants.verify.localized : Constants.save.localized)
                Image(UIConstants.Symbols.arrowRightWhite)
                    .resizable()
                    .frame(width: UIConstants.Layout.screenPadding,
                           height: UIConstants.Layout.screenPadding)
                Spacer()
            }
            .font(Design.Font.button)
            .foregroundColor(.white)
            .padding()
            .frame(height: UIConstants.Layout.ActionButton.height)
            .background(
                isPinComplete ? Design.Color.appGradient.opacity(UIConstants.Opacity.highest)
                              : Design.Color.appGradient.opacity(UIConstants.Opacity.medium)
            )
            .cornerRadius(UIConstants.Layout.screenPadding)
            .shadow(color: Color.black.opacity(0.2), radius: UIConstants.Layout.verticalPadding, x: 0, y: 5)
        }
        .padding(.horizontal, 12.5)
        .disabled(!isPinComplete)
    }

    // MARK: - Back Button
    @ViewBuilder
    private func backButton() -> some View {
        Button(action: { dismiss() }) {
            Image(UIConstants.Symbols.crossBlack)
                .renderingMode(.template)
                .resizable()
                .foregroundColor(.white)
                .frame(width: UIConstants.Layout.menuIconWidth,
                       height: UIConstants.Layout.menuIconWidth)
        }
        .padding(.top, UIConstants.Layout.backButtonPadding)
        .padding(.leading, UIScreen.main.bounds.width - UIConstants.Layout.Height.tapTarget)
    }
}
