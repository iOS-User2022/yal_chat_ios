//
//  CallStateManager.swift
//  YAL
//
//  Created by Sheetal Jha on 02/10/25.
//

import SwiftUI
import Combine

class CallStateManager: ObservableObject {
    static let shared = CallStateManager()
    
    @Published var currentCallState: CallState = .end
    @Published var currentParticipants: [ContactModel] = []
    @Published var currentRoomId: String?
    @Published var isVideo: Bool = false
    @Published var currentUserId: String?
    @Published var isCurrentUserInCall: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let stateQueue = DispatchQueue(label: "com.yal.callstate", qos: .userInitiated)
    
    private init() {
        setupCallStateListener()
    }
    
    private func setupCallStateListener() {
        NotificationCenter.default.publisher(for: .callStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
//                self?.handleCallStateNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    
    func setCurrentRoomId(_ roomId: String) {
        currentRoomId = roomId
    }
    
    func getCurrentRoomId() -> String? {
        return currentRoomId
    }
    
    func updateParticipants(_ participants: [ContactModel]) {
        stateQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.currentParticipants = participants
                self?.updateCurrentUserInCallStatus()
            }
        }
    }
    
    func setCurrentUser(_ userId: String) {
        stateQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.currentUserId = userId
                self?.updateCurrentUserInCallStatus()
            }
        }
    }
    
    private func updateCurrentUserInCallStatus() {
        guard let userId = currentUserId else {
            isCurrentUserInCall = false
            return
        }
        
        isCurrentUserInCall = currentParticipants.contains { $0.userId == userId }
    }
    

}
