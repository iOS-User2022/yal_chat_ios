//
//  ContactsViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import Foundation
import Combine

class ContactListViewModel: ObservableObject {
    @Published var sections: [ContactSection] = []
    @Published var accessStatus: ContactAccessStatus = .unknown
    @Published var alertModel: AlertViewModel? = nil
    private let contactSyncCoordinator: ContactSyncCoordinator

    private var cancellables = Set<AnyCancellable>()

    init(contactSyncCoordinator: ContactSyncCoordinator) {
        self.contactSyncCoordinator = contactSyncCoordinator
        observeEnrichedContacts()
        observeAccessStatus()
    }

    func startContactSync() {
        ContactManager.shared.syncContacts()
    }

    private func observeAccessStatus() {
        ContactManager.shared.$accessStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.accessStatus = status
            }
            .store(in: &cancellables)
    }
    
    private func observeEnrichedContacts() {
        self.contactSyncCoordinator.enrichedContactsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contactModels in
                self?.sections = ContactSection.from(contactModels: contactModels)
                self?.accessStatus = .granted
            }
            .store(in: &cancellables)
    }

    func filteredSections(for search: String) -> [ContactSection] {
        if search.isEmpty {
            return sections
        } else {
            return sections.compactMap { section in
                let filtered = section.contacts.filter {
                    $0.fullName?.lowercased().contains(search.lowercased()) ?? false || $0.phoneNumber.contains(search.lowercased())
                }
                return filtered.isEmpty ? nil : ContactSection(letter: section.letter, contacts: filtered)
            }
        }
    }

    func showAlertForDeniedPermission() {
        alertModel = AlertViewModel(
            title: "Permission Needed",
            subTitle: "Please allow contact access from Settings to display contacts.",
            actions: [
                AlertActionModel(title: "Cancel", style: .secondary, action: {}),
                AlertActionModel(title: "Open Settings", style: .primary) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            ]
        )
    }

    func showAlertForRestrictedAccess() {
        alertModel = AlertViewModel(
            title: "Access Restricted",
            subTitle: "Contact access is restricted by parental controls or system policies.",
            actions: [
                AlertActionModel(title: "OK", style: .primary, action: {})
            ]
        )
    }
}
