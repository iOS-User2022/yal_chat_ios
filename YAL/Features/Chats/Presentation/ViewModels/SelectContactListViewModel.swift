//
//  SelectContactListViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 04/05/25.
//


import Foundation
import Combine

class SelectContactListViewModel: ObservableObject {
    @Published var search: String = ""

    @Published var yalContacts: [ContactLite] = []
    @Published var otherContacts: [ContactLite] = []
    @Published var frequentlyContacted: [ContactLite] = []
    @Published var filteredYalContacts: [ContactLite] = []
    @Published var filteredOtherContacts: [ContactLite] = []
    @Published var filteredFrequentlyContacted: [ContactLite] = []
    @Published var currentUser: ContactLite?
    @Published var excludedContactIds: [String] = []

    @Published var accessStatus: ContactAccessStatus = .unknown
    private let contactSyncCoordinator: ContactSyncCoordinator
    private var cancellables = Set<AnyCancellable>()
    let apiManager: ApiManageable

    init(apiManager: ApiManageable, contactSyncCoordinator: ContactSyncCoordinator) {
        self.apiManager = apiManager
        self.contactSyncCoordinator = contactSyncCoordinator
        
        if let profileModel = Storage.get(for: .cachedProfile, type: .userDefaults, as: EditableProfile.self),
           let authSession = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self) {
            self.currentUser = ContactLite(userId: authSession.userId, fullName: profileModel.name, phoneNumber: profileModel.mobile)
        }
        
        ContactManager.shared.$accessStatus
            .sink { [weak self] status in
                self?.accessStatus = status
            }
            .store(in: &cancellables)
        
        contactSyncCoordinator.enrichedContactsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contactModels in
                self?.updateContactGroups(contactModels: contactModels)
                // Fix: also update the filtered arrays so search applies immediately
                self?.updateFilteredContacts(with: self?.search ?? "", currentUserId: self?.currentUser?.userId)
            }
            .store(in: &cancellables)
        
        $search
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.updateFilteredContacts(with: searchText, currentUserId: self?.currentUser?.userId)
            }
            .store(in: &cancellables)
    }

    func startContactSync() {
        ContactManager.shared.syncContacts()
        // Optionally, immediately update filtered
        updateFilteredContacts(with: search, currentUserId: self.currentUser?.userId)
    }

    private func updateContactGroups(contactModels: [ContactLite]) {
        yalContacts = contactModels
                .filter { m in
                    guard let userId = m.userId, !userId.isEmpty else { return false }
                    guard let name = m.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty else { return false }
                    let phone = m.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    if phone.isEmpty { return false }
                    return !excludedContactIds.contains(userId)
                }
                .sorted { lhs, rhs in
                    let lName = lhs.fullName?.lowercased() ?? ""
                    let rName = rhs.fullName?.lowercased() ?? ""
                    if lName == rName {
                        return (lhs.userId ?? "") < (rhs.userId ?? "")
                    }
                    return lName < rName
                }
        otherContacts = contactModels
            .filter { contact in
                (contact.userId?.isEmpty ?? true)
                && !(contact.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .sorted { ($0.fullName?.lowercased() ?? "") < ($1.fullName?.lowercased() ?? "") }
    }

    func getSections() -> [SelectContactSection] {
        var sections: [SelectContactSection] = []

        if !filteredYalContacts.isEmpty {
            sections.append(SelectContactSection(letter: "Contact on YAL.ai", contacts: filteredYalContacts))
        }

        if !filteredOtherContacts.isEmpty {
            sections.append(SelectContactSection(letter: "Invite on YAL.ai", contacts: filteredOtherContacts))
        }

        return sections
    }
    
    func updateFilteredContacts(with search: String, currentUserId: String?) {
        let isSelf: (ContactLite) -> Bool = { contact in
            guard let currentUserId else { return false }
            return contact.userId == currentUserId
        }

        if search.isEmpty {
            filteredYalContacts = yalContacts.filter { !isSelf($0) }
            filteredOtherContacts = otherContacts.filter { !isSelf($0) }
        } else {
            let lower = search.lowercased()
            filteredYalContacts = yalContacts.filter {
                (($0.userId?.isEmpty) != nil) && !isSelf($0) &&
                ($0.fullName?.lowercased().contains(lower) ?? false ||
                 $0.phoneNumber.contains(lower)) || $0.displayName?.contains(lower) ?? false
            }
            filteredOtherContacts = otherContacts.filter {
                !isSelf($0) &&
                ($0.fullName?.lowercased().contains(lower) ?? false ||
                 $0.phoneNumber.contains(lower))
            }
        }
    }
}
