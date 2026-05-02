//
//  CallScreen.swift
//  YAL
//
//  Created by Pavithra MH on 16/09/25.
//

import SwiftUI
import LiveKit
import Combine

struct CallScreen: View {
    @EnvironmentObject var callManager: CallManager
    @StateObject private var viewModel = CallViewModel.shared
    @StateObject private var selectContactListViewModel: SelectContactListViewModel
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var roomDetailsViewModel: RoomDetailsViewModel
    @StateObject private var rlViewModel: RoomListViewModel

    @State private var participants: [ContactModel]?
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveDialog: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var selectedParticipant: Participant?
    @State private var navigateToCallScreen = false
    @State private var navPath = NavigationPath()
    @State private var showAddMemberSheet = false
    @State private var selectedToAdd: [ContactLite] = []
    @State private var invitedToAdd: [ContactLite] = []
    
    let roomModel: RoomModel
    
    init(roomModel: RoomModel, callState: CallState) {
        self.roomModel = roomModel
        
        let selectContactListViewModel = DIContainer.shared.container.resolve(SelectContactListViewModel.self)!
        selectContactListViewModel.excludedContactIds = roomModel.activeParticipants.compactMap { $0.userId }
        _selectContactListViewModel = StateObject(wrappedValue: selectContactListViewModel)
        
        var rlViewModel = DIContainer.shared.container.resolve(RoomListViewModel.self)!
        _rlViewModel = StateObject(wrappedValue: rlViewModel)
        
        let rdViewModel = DIContainer.shared.container.resolve(RoomDetailsViewModel.self, argument: roomModel)!
        _roomDetailsViewModel = StateObject(wrappedValue: rdViewModel)
        
        let vm = DIContainer.shared.container.resolve(ChatViewModel.self)!
        _chatViewModel = StateObject(wrappedValue: vm)
                
        self.participants = self.roomModel.participants
        
        CallViewModel.shared.injectParticipants(self.roomModel, callState: callState)
    }

    var body: some View {
        ZStack {
            if (CallManager.shared.isVideoCall && CallManager.shared.callState == .ongoing){
                VStack {
                    Spacer()
                    callContentView()
                    Spacer()
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 40, trailing: 0))
                .background(Color.black)
            }else{
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 3/255, green: 27/255, blue: 74/255),
                        Color(red: 13/255, green: 43/255, blue: 84/255),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                VStack{
                    
                    ZStack {
                        HStack {
                            backButton()
                            Spacer()
                        }
                        
                        VStack(spacing: 2) {
                            Text(getTitle())
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("End-to-end encrypted")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        if CallManager.shared.callState == .ongoing {
                            HStack {
                                Spacer()
                                addParticipantButton()
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
                    
                    Spacer()
                    callContentView()
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(EdgeInsets(top: 40, leading: 0, bottom: 40, trailing: 0))
            }
            
            // MARK: Remove confirmation popup
            if showRemoveDialog, let selected = selectedParticipant {
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                        .ignoresSafeArea()
                        .opacity(0.95)
                    
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation { showRemoveDialog = false }
                        }
                    
                    RemoveConfirmationView(
                        participantName: selected.name ?? "",
                        removeAction: {
                            removeParticipant(selected)
                            withAnimation { showRemoveDialog = false }
                        },
                        cancelAction: {
                            withAnimation { showRemoveDialog = false }
                        }
                    )
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 32)
                    .transition(.scale.combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .animation(.easeInOut, value: showRemoveDialog)
        .onReceive(NotificationCenter.default.publisher(for: .dismissCallView)) { _ in
            dismiss()
        }
        .sheet(isPresented: $showAddMemberSheet) {
            NewGroupContactSelectorView(
                viewModel: selectContactListViewModel,
                selectedContacts: $selectedToAdd,
                invitedContacts: $invitedToAdd,
                onContinue: {
                    showAddMemberSheet = false
                    selectedToAdd.removeAll()
                    invitedToAdd.removeAll()
                    
                    //sendinvites in individual chat
                    if let currentUserId = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)?.userId {
                        for user in $selectedToAdd {
                            if let rm = rlViewModel.findExistingDirectRoom(with: user.id){
                                chatViewModel.currentRoomId = rm.id
                                chatViewModel.sendCallMessage(callState: .outgoing, isVideo: CallManager.shared.isVideoCall, eventId: UUID().uuidString, content: "Invited \(viewModel.roomModel?.id)") { result in
                                    switch result {
                                        case .success(let newEventId):
                                            print("Individual invitation sent successfully: \(newEventId)")
                                            
                                        case .failure(let error):
                                            print("Failed to Individual invitation :", error.localizedDescription)
                                    }
                                }
                            }else{
                                rlViewModel.createRoom(currentUser: currentUserId, users: [user.id] , roomName: "", roomDisplayImageUrl: "", completion: { roomModel in
                                    chatViewModel.currentRoomId = roomModel?.id
                                    chatViewModel.sendCallMessage(callState: .outgoing, isVideo: CallManager.shared.isVideoCall, eventId: UUID().uuidString, content: "Invited \(viewModel.roomModel?.id)") { result in
                                        switch result {
                                            case .success(let newEventId):
                                                print("Individual invitation sent successfully: \(newEventId)")
                                                
                                            case .failure(let error):
                                                print("Failed to Individual invitation :", error.localizedDescription)
                                        }
                                    }
                                })
                            }
                        }
                    }
                },
                onDismiss: {
                    selectedToAdd.removeAll()
                    invitedToAdd.removeAll()
                    showAddMemberSheet = false
                }
            )
        }
    }
    
    func getTitle() ->  String{
        if CallManager.shared.callState == .outgoing {
            return "Outgoing call"
        } else if CallManager.shared.callState == .ongoing {
            return "Ongoing call"
        }else if  CallManager.shared.callState == .end {
            return "Call ended"
        }
        
        return "Call"
    }
    // MARK: - Call content section
    @ViewBuilder
    private func callContentView() -> some View {
        switch CallManager.shared.callState {
            case .incoming:
                IncomingCallView(
                    onAccept: {
                        CallManager.shared.callState = .ongoing
                        viewModel.connect()
                    },
                    onDecline: {
                        CallManager.shared.callState = .decline
                        viewModel.declineCall()
                    }
                )
                .onAppear {
                    CallManager.shared.updateCallStatus()
                }
                
            case .outgoing:
                OutgoingCallView(
                    viewModel: viewModel,
                    participants: roomModel.participants
                )
                .onAppear {
                    viewModel.connect()
                }
                
            case .ongoing:
                if CallManager.shared.isVideoCall {
                    ZStack {
                        // Keep your existing OngoingVideoView on top for UI overlays, tap handlers, etc.
                        OngoingVideoView(
                            viewModel: viewModel,
                            roomModel: roomModel
                        ) { contact in
                            selectedParticipant = contact
                            withAnimation(.spring()) { showRemoveDialog = true }
                        }
                    }
                    .onAppear {
                        if !viewModel.isConnected {
                            CallManager.shared.updateCallStatus()
                            viewModel.connect()
                        }
                    }
                }else{
                    OngoingCallView(
                        viewModel: viewModel,
                        roomModel: roomModel
                    ) { contact in
                        print("CallScreen: contact tapped =", contact.name ?? "nil")
                        selectedParticipant = contact
                        withAnimation(.spring()) {
                            showRemoveDialog = true
                        }
                    }
                    .onAppear {
                        if !viewModel.isConnected {
                            CallManager.shared.updateCallStatus()
                            viewModel.connect()
                        }
                    }
                }
            case .decline, .declineWithMessage, .end:
                callEndedUI()
                    .onAppear(){
                        CallManager.shared.endCall()
                    }
            case .idle:
                callEndedUI()
                    .onAppear(){
                        CallManager.shared.endCall()
                    }
                
        }
    }
    
    private func callEndedUI() -> some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 40) {
                var eventId = UUID().uuidString
                Button {
                    chatViewModel.currentRoomId = roomModel.id
                    chatViewModel.sendCallMessage(
                        callState: .outgoing,
                        isVideo: false,
                        eventId: eventId
                    ) { result in
                        switch result {
                            case .success(let newEventId):
                                navigateToCallScreen = false   // ✅ trigger navigation
                                eventId = newEventId
                                CallManager.shared.presentCall(for: roomModel)
//                                chatViewModel.becomeActiveCallMessageHandler(eventID: roomModel.id)
                                callManager.eventId = newEventId
                                callManager.callState = .outgoing
                                callManager.updateCallStatus()
                            case .failure(let error):
                                print("Failed to send call message:", error.localizedDescription)
                        }
                    }
                } label: {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                }
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "message.fill")
                            .foregroundColor(.black)
                            .font(.title2)
                    )
                    .onTapGesture {
                        dismiss()
                    }
                    .offset(y: dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if gesture.translation.height < 0 {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) { dragOffset = .zero }
                            }
                    )
            }
            .padding(.bottom, 10)
        }
    }
    
    private func backButton() -> some View {
        Button(action: {
            CallManager.shared.hideCallView()
        }) {
            Image("backArrow")
                .foregroundColor(.white)
                .font(.title2)
                .padding(10)
        }
    }
    
    private func addParticipantButton() -> some View {
        Button(action: {
            showAddMemberSheet = true
        }) {
            Image("addMembers")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
        }
        .frame(width: 50, height: 50)
    }
    private func removeParticipant(_ p: Participant) {
//        participants?.removeAll { $0.id == p.id }
        chatViewModel.currentRoomId = roomModel.id
        chatViewModel.sendCallUpdate(
            callState: .outgoing,
            isVideo: false,
            eventId: CallManager.shared.eventId ?? UUID().uuidString,
            content: "Remove \(p.identity!.stringValue)"
        ) { result in
            switch result {
                case .success(let newEventId):
                    print("livekit Message sent successfully: \(newEventId)")
                    
                case .failure(let error):
                    print("Failed to send call message:", error.localizedDescription)
            }
        }
    }
}

// MARK: - RemoveConfirmationView (unchanged)
struct RemoveConfirmationView: View {
    let participantName: String
    let removeAction: () -> Void
    let cancelAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Remove Participant?")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Are you sure you want to remove \(participantName) from the call?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            VStack(spacing: 12) {
                Button(action: removeAction) {
                    Text("Remove")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 8/255, green: 36/255, blue: 86/255))
                        )
                        .foregroundColor(.white)
                }
                
                Button(action: cancelAction) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 20)
    }
}
