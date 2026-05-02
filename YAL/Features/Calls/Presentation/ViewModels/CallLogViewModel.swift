//
//  CallLogViewModel.swift
//  YAL
//
//  Created by Sheetal Jha on 26/09/25.
//

import Foundation
import Combine
import Contacts

class CallLogViewModel: ObservableObject {
    @Published var callLogs: [CallLogEntry] = []
    @Published var filteredCallLogs: [CallLogEntry] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = "" {
        didSet {
            filterCallLogs()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var selectedFilter: CallFilter = .all
    private let callLogService: CallLogServiceProtocol
    
    init(callLogService: CallLogServiceProtocol = CallLogService.shared) {
        self.callLogService = callLogService
        loadCallLogs()
        setupCallLogListener()
        loadMockDataIfEmpty()
        filterCallLogs()
    }
    
    func updateFilter(_ filter: CallFilter) {
        selectedFilter = filter
        filterCallLogs()
    }
    
    private func filterCallLogs() {
        var filtered = callLogs
        
        if !searchText.isEmpty {
            filtered = filtered.filter { callLog in
                callLog.contactName.localizedCaseInsensitiveContains(searchText) ||
                callLog.contactPhoneNumber.contains(searchText)
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .missed:
            filtered = filtered.filter { $0.callDirection == .missed || $0.callDirection == .missedOutgoing }
        }
        
        filtered.sort { $0.timestamp > $1.timestamp }
        
        filteredCallLogs = filtered
    }
    
    func makeCall(to entry: CallLogEntry) {
        print("Making call to \(entry.contactName)")
    }
    
    func startVideoCall(to entry: CallLogEntry) {
        print("Starting video call to \(entry.contactName)")
    }
    
    private func loadCallLogs() {
        callLogs = callLogService.getCallLogs()
    }
    
    private func setupCallLogListener() {
        if let service = callLogService as? CallLogService {
            service.$callLogs
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newCallLogs in
                    self?.callLogs = newCallLogs
                    self?.filterCallLogs()
                }
                .store(in: &cancellables)
        }
    }
    
    // TODO: Remove once real calling is integrated
    private func loadMockDataIfEmpty() {
        let logs: [ChatMessageModel] = DBManager.shared.fetchCallLogsMessages()
        let chatRepository = DIContainer.shared.container.resolve(ChatRepository.self)!

        var callLogsData = [CallLogEntry]()
        for log in logs {
            let timestampInSeconds = Double(log.timestamp) / 1000.0
            let timestampDate = Date(timeIntervalSince1970: timestampInSeconds)
            var currentNameString = ""
            if let room = chatRepository.getExistingRoomModel(roomId: log.roomId) {
                currentNameString = room.name
            }else if let val = ContactManager.shared.contact(for: log.sender) {
                currentNameString = val.fullName ?? ""
            }
            if currentNameString.isEmpty {
                currentNameString = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self) ?? log.id
            }
            
            print(currentNameString)
            callLogsData.append(
                CallLogEntry(
                    contactId: log.id,
                    contactName: currentNameString,
                    contactPhoneNumber: log.eventId,
                    callType: log.msgType == "m.voiceCall" ? .voice : .video,
                    callDirection: log.sender == log.currentUserId ? .outgoing : .incoming,
                    timestamp: timestampDate
                )
            )
        }
        
        if callLogs.isEmpty {
            if let service = callLogService as? CallLogService {
                service.callLogs.append(contentsOf: callLogsData)
            }
        }
        
        
    }

    func startCallFromContact(_ contact: CNContact) {
        guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else { return }
        let fullName = "\(contact.givenName) \(contact.familyName)"
            .trimmingCharacters(in: .whitespaces)

        // Hook into your existing call logic here
        // Example:
        // CallManager.shared.initiateCall(to: phoneNumber, displayName: fullName)
        print(" Calling \(fullName) at \(phoneNumber)")
    }
}
