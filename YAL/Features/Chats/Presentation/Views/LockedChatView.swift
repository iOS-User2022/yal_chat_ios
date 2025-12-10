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
                .background(Design.Color.chatBackground)
                floatingButton
                    .position(
                        x: geometry.size.width - 20 - 22,
                        y: geometry.size.height - 12 - 55
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
            VStack(spacing: 24) {
                ForEach(rooms) { room in
                    roomButton(for: room)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Design.Color.tabHighlight.opacity(0.12))
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
        .frame(height: 48)
        .opacity((unblockRooms.contains(where: { $0.id == room.id }) || unblockRooms.count == 0) ? 1.0 : 0.5)
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
                        Image("back-long")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                    }
                    .padding(.leading, 10)
                    .frame(width: 40, height: 40)
                }
                Text("Locked Chats")
                    .font(Design.Font.semiBold(16.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if unblockRooms.count > 0 {
                    Text("Remove")
                        .font(Design.Font.semiBold(14.0))
                        .frame(alignment: .leading)
                        .padding(.trailing, 10)
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
        .background(Design.Color.white)
    }
    
    var floatingButton: some View {
        Button(action: {
            navPath.append(NavigationTarget.manageLockedChats)
        }) {
            ZStack {
                CustomRoundedCornersShape(radius: 12, roundedCorners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Design.Color.appGradient)
                    .frame(width: 44, height: 44)
                
                Image("call-add")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        }
        .shadow(radius: 10)
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
                VStack(spacing: 12) {
                    enableToggleSection
                    
                    Group {
                        lockSecuritySection
                    }
                    .disabled(!isLockedChatsEnabled)
                    .opacity(isLockedChatsEnabled ? 1.0 : 0.6)

                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .background(Design.Color.white.ignoresSafeArea())
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
        HStack(spacing: 8) {
            Button(action: {
                if !navPath.isEmpty {
                    navPath.removeLast()
                } else {
                    onBack()
                }
            }) {
                Image("back-long")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }

            Text("Manage Locked Chats")
                .font(Design.Font.semiBold(16))
                .foregroundColor(Design.Color.primaryText)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaTop() + 12)
        .padding(.bottom, 8)
    }

    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }
}

// MARK: - Sections
private extension ManageLockedChatsView {
    var enableToggleSection: some View {
        HStack {
            Text("Enable Locked Chats")
                .font(Design.Font.regular(15))
                .foregroundColor(Design.Color.primaryText)

            Spacer()

            Toggle("", isOn: $isLockedChatsEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Design.Color.blue))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.gray.opacity(0.1))
    }

    var lockSecuritySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lock chat security")
                .font(Design.Font.semiBold(14))
                .foregroundColor(Design.Color.primaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            ForEach(LockSecurityOption.allCases, id: \.self) { option in
                Button(action: {
                    selectedSecurityOption = option
                    if option == .pin {
                        showSetPinView = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: selectedSecurityOption == option ? "circle.inset.filled" : "circle")
                            .foregroundColor(.black)
                            .font(.system(size: 16, weight: .semibold))

                        Text(option.label)
                            .font(Design.Font.regular(14))
                            .foregroundColor(Design.Color.primaryText)

                        Spacer()

                        if option == .pin {
                            Text("Set PIN")
                                .font(Design.Font.semiBold(14))
                                .foregroundColor(.black)
                                .underline(true, color: .black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color.gray.opacity(0.1))
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
            return "Biometric – use system default"
        case .faceID:
            return "Face ID – use system default"
        case .pin:
            return "PIN"
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
        pinDigits.joined().count == 6
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 120)
                
                Text(isConfirmMode ? "Verify PIN" : "Set PIN")
                    .font(Design.Font.bold(24))
                    .foregroundColor(Design.Color.headingText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
                
                subHeadingSection()
                Spacer().frame(height: 24)
                
                // Reuse the same OTP-style input
                otpInputFields()
                
                Spacer().frame(height: 48)
                
                verifyButton()
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .background(Color.white)
            
            backButton()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private func subHeadingSection() -> some View {
        (
            Text(!isConfirmMode ? "Set your 6-digit PIN to secure your chats." : "Enter the 6-digit PIN you set earlier to unlock your chat.")
                .foregroundColor(Design.Color.headingText.opacity(0.7))
                .font(Design.Font.body)
        )
        .multilineTextAlignment(.center)
    }

    // MARK: - OTP Style Input
    @ViewBuilder
    private func otpInputFields() -> some View {
        ZStack {
            hiddenTextField()
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
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
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .focused($focusedIndex, equals: 0)
    }

    @ViewBuilder
    private func otpBox(index: Int) -> some View {
        VStack(spacing: 2) {
            Spacer()
            Text(pinDigits[index])
                .font(Design.Font.regular(16))
                .foregroundColor(Design.Color.primaryText.opacity(0.7))
            if pinDigits[index].isEmpty {
                Rectangle()
                    .frame(width: 11, height: 1)
                    .foregroundColor(Design.Color.primaryText.opacity(0.7))
                    .padding(.horizontal, 8)
                Spacer().frame(height: 3)
            }
        }
        .padding(7)
        .frame(width: 27, height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 0.5)
                .stroke(Design.Color.navy, lineWidth: 1)
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
            HStack(spacing: 12) {
                Spacer()
                Text(isConfirmMode ? "Verify" : "Save")
                Image("arrow-right-white")
                    .resizable()
                    .frame(width: 20, height: 20)
                Spacer()
            }
            .font(Design.Font.button)
            .foregroundColor(.white)
            .padding()
            .frame(height: 60)
            .background(
                isPinComplete ? Design.Color.appGradient.opacity(1.0)
                              : Design.Color.appGradient.opacity(0.6)
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 12.5)
        .disabled(!isPinComplete)
    }

    // MARK: - Back Button
    @ViewBuilder
    private func backButton() -> some View {
        Button(action: { dismiss() }) {
            Image("cross-black")
                .resizable()
                .frame(width: 24, height: 24)
        }
        .padding(.top, 50)
        .padding(.leading, UIScreen.main.bounds.width - 44)
    }
}
