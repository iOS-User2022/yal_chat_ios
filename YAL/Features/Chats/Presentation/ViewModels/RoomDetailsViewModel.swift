//
//  RoomDetailsViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 01/07/25.
//

import Foundation
import Combine

final class RoomDetailsViewModel: ObservableObject {
    @Published var room: RoomModel
    @Published var isFavorite: Bool = false
    @Published var alertModel: AlertViewModel? = nil

    private let roomService: RoomServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(roomService: RoomServiceProtocol, room: RoomModel) {
        self.roomService = roomService
        self.room = room
        self.isFavorite = roomService.getFavoriteRooms().contains { !$0.isEmpty && $0 == room.id }
    }
    
    func showAlertForDeniedPermission(success: Bool) {
        var title = "Profile Updated Successfully"
        var subTitle = "Your changes have been saved and updated."
        var image = "tick-circle-green"
        if !success {
             title = "Profile Update Failed"
             subTitle = "An error occurred while saving your changes."
             image = "cancel"
        }
        alertModel = AlertViewModel(
            title: title,
            subTitle: subTitle,
            imageName: image,
            actions: [
                AlertActionModel(title: "OK", style: .secondary, action: {})
            ]
        )
    }

    // MARK: - Actions

    func kickOutUser(_ user: ContactModel, completion: @escaping (Result<Void, APIError>) -> Void) {
        LoaderManager.shared.show()
        roomService
            .kickUserFromRoom(room: room, user: user, reason: "")
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionResult in
                    guard let self else { return }
                    switch completionResult {
                    case .finished:
                        self.showAlertForKickOut(true, member: user)
                        completion(.success(()))
                    case .failure(let error):
                        self.showAlertForKickOut(false, member: user)
                        completion(.failure(error))
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    func leaveRoom(completion: @escaping (Result<Void, APIError>) -> Void) {
        LoaderManager.shared.show()
        roomService.leaveRoom(room: room, reason: "")
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                switch comp {
                case .finished:
                    self?.showAlertForLeaveRoom(true)
                case .failure( _):
                    self?.showAlertForLeaveRoom(false)
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func deleteRoom(completion: @escaping (Result<Void, APIError>) -> Void) {
        LoaderManager.shared.show()
        roomService.deleteRoom(room: room, reason: "Admin deleted the room")
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                switch comp {
                case .finished:
                    self?.showAlertForDeleteRoom(true)
                    completion(.success(()))
                case .failure(let e):
                    self?.showAlertForDeleteRoom(false)
                    completion(.failure(e))
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func inviteUsers(users: [ContactLite]) {
        LoaderManager.shared.show()
        roomService.inviteUsersToRoom(room: room, users: users, reason: "Admin invited the user to the room")
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                if case .failure(let e) = comp {
                    self?.showAlertForInvitesSummary(ok: 0, failedNames: users.map {
                        $0.fullName ?? $0.displayName ?? $0.phoneNumber
                    })
                }
            }, receiveValue: { [weak self] results in
                guard let self else { return }
                let failedNames: [String] = results.compactMap { (u, r) in
                    switch r {
                    case .success: return nil
                    case .unsuccess:
                        return u.fullName ?? u.displayName ?? u.phoneNumber
                    }
                }
                let ok = results.count - failedNames.count
                self.showAlertForInvitesSummary(ok: ok, failedNames: failedNames)
            })
            .store(in: &cancellables)
    }

    func toggleFavorite() {
        roomService.toggleFavoriteRoom(roomID: room.id)
        isFavorite = roomService.getFavoriteRooms().contains { !$0.isEmpty && $0 == room.id }
    }

    func updateRoomName(to newName: String) {
        LoaderManager.shared.show()
        roomService.updateRoomName(room: room, newName: newName)
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .finished:
                    self.showAlertForGroupNameUpdate(success: true)
                case .failure(let error):
                    self.showAlertForGroupNameUpdate(success: false)
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func updateRoomImage(to newImage: String) {
        LoaderManager.shared.show()
        roomService.updateRoomImage(room: room, newUrl: newImage)
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .handleEvents(receiveCompletion: { _ in
                DispatchQueue.main.async { LoaderManager.shared.hide() }
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                switch comp {
                case .finished:
                    self?.showAlertForRoomImageUpdate(true)
                case .failure:
                    self?.showAlertForRoomImageUpdate(false)
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    // MARK: - Alerts

    private func showAlertForGroupNameUpdate(success: Bool) {
        let model = AlertViewModel(
            title: success ? "Group Name Updated Successfully" : "Group Name Update Failed",
            subTitle: success ? "Your changes have been saved." : "An error occurred while saving changes.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: {})]
        )
        DispatchQueue.main.async { [weak self] in
            self?.alertModel = model
        }
    }
    
    private func showAlertForLeaveRoom(_ success: Bool) {
        let model = AlertViewModel(
            title: success ? "Exited Group" : "Exit Failed",
            subTitle: success
                ? "You have left \(room.name)."
                : "Could not leave the group. Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: {})]
        )
        DispatchQueue.main.async { [weak self] in self?.alertModel = model }
    }

    private func showAlertForDeleteRoom(_ success: Bool) {
        let model = AlertViewModel(
            title: success ? "Group Deleted" : "Delete Failed",
            subTitle: success
                ? "“\(room.name)” has been deleted."
                : "We couldn’t delete this group. Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: {})]
        )
        DispatchQueue.main.async { [weak self] in self?.alertModel = model }
    }

    private func showAlertForRoomImageUpdate(_ success: Bool) {
        let model = AlertViewModel(
            title: success ? "Group Photo Updated" : "Image Update Failed",
            subTitle: success
                ? "The group image has been updated successfully."
                : "Could not update the group image. Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: {})]
        )
        DispatchQueue.main.async { [weak self] in self?.alertModel = model }
    }

    /// Invite summary: call with counts (use your receiveValue to compute)
    private func showAlertForInvitesSummary(ok: Int, failedNames: [String]) {
        let total = ok + failedNames.count
        let (title, subTitle, image): (String, String, String)

        if failedNames.isEmpty {
            title = "Invites Sent"
            subTitle = "\(ok) invite\(ok == 1 ? "" : "s") sent successfully."
            image = "tick-circle-green"
        } else if ok == 0 {
            title = "All Invites Failed"
            let preview = failedNames.prefix(3).joined(separator: ", ")
            subTitle = "Failed (\(total)): \(preview)\(failedNames.count > 3 ? " and more…" : "")"
            image = "cancel"
        } else {
            title = "Some Invites Failed"
            let preview = failedNames.prefix(3).joined(separator: ", ")
            subTitle = "\(ok) sent, \(failedNames.count) failed: \(preview)\(failedNames.count > 3 ? " and more…" : "")"
            image = "cancel"
        }

        let model = AlertViewModel(
            title: title,
            subTitle: subTitle,
            imageName: image,
            actions: [AlertActionModel(title: "OK", style: .secondary, action: {})]
        )
        DispatchQueue.main.async { [weak self] in self?.alertModel = model }
    }
    
    private func showAlertForKickOut(_ success: Bool, member: ContactModel) {
        let who = displayName(for: member)
        alertModel = AlertViewModel(
            title: success ? "Member Removed" : "Remove Failed",
            subTitle: success ? "\(who) has been removed from the group."
                             : "Couldn't remove \(who). Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: { [weak self] in
                self?.alertModel = nil
            })]
        )
    }

    private func showAlertForDeleteGroup(_ success: Bool) {
        alertModel = AlertViewModel(
            title: success ? "Group Deleted" : "Delete Failed",
            subTitle: success ? "This group has been deleted for all participants."
                              : "We couldn’t delete the group. Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: { [weak self] in
                self?.alertModel = nil
            })]
        )
    }

    private func showAlertForLeaveGroup(_ success: Bool) {
        alertModel = AlertViewModel(
            title: success ? "Left Group" : "Leave Failed",
            subTitle: success ? "You have left this group."
                              : "We couldn’t process leave. Please try again.",
            imageName: success ? "tick-circle-green" : "cancel",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: { [weak self] in
                self?.alertModel = nil
            })]
        )
    }

    private func showAlertForClearChat() {
        alertModel = AlertViewModel(
            title: "Chat Cleared",
            subTitle: "Messages have been cleared on this device.",
            imageName: "tick-circle-green",
            actions: [AlertActionModel(title: "OK", style: .secondary, action: { [weak self] in
                self?.alertModel = nil
            })]
        )
    }

    // MARK: - Confirm models (return AlertViewModel; the View presents it)
    private func displayName(for m: ContactModel) -> String {
        if let n = m.fullName, !n.isEmpty { return n }
        if let n = m.displayName, !n.isEmpty { return n }
        return m.phoneNumber
    }
    
    func makeConfirmKickAlert(for member: ContactModel) -> AlertViewModel {
        let who = displayName(for: member)
        return AlertViewModel(
            title: "Remove \(who)?",
            subTitle: "They will be removed from this group.",
            imageName: "warning",
            actions: [
                AlertActionModel(title: "Cancel", style: .secondary, action: { [weak self] in
                    self?.alertModel = nil
                }),
                AlertActionModel(title: "Remove", style: .destructive, action: { [weak self] in
                    guard let self else { return }
                    self.alertModel = nil
                    self.kickOutUser(member) { [weak self] result in
                        switch result {
                        case .success: self?.showAlertForKickOut(true, member: member)
                        case .failure: self?.showAlertForKickOut(false, member: member)
                        }
                    }
                })
            ]
        )
    }

    func makeConfirmDeleteGroupAlert(onSuccess: (() -> Void)? = nil) -> AlertViewModel {
        AlertViewModel(
            title: "Delete Group?",
            subTitle: "This will delete the group for all participants. This action cannot be undone.",
            imageName: "warning",
            actions: [
                AlertActionModel(title: "Cancel", style: .secondary, action: { [weak self] in
                    self?.alertModel = nil
                }),
                AlertActionModel(title: "Delete", style: .destructive, action: { [weak self] in
                    guard let self else { return }
                    self.alertModel = nil
                    self.deleteRoom { [weak self] result in
                        switch result {
                        case .success:
                            self?.showAlertForDeleteGroup(true)
                            onSuccess?()
                        case .failure:
                            self?.showAlertForDeleteGroup(false)
                        }
                    }
                })
            ]
        )
    }

    func makeConfirmLeaveGroupAlert() -> AlertViewModel {
        AlertViewModel(
            title: "Leave Group?",
            subTitle: "You won’t receive new messages from this group after leaving.",
            imageName: "warning",
            actions: [
                AlertActionModel(title: "Cancel", style: .secondary, action: { [weak self] in
                    self?.alertModel = nil
                }),
                AlertActionModel(title: "Leave", style: .destructive, action: { [weak self] in
                    guard let self else { return }
                    self.alertModel = nil
                    self.leaveRoom { [weak self] result in
                        switch result {
                        case .success:
                            self?.showAlertForLeaveGroup(true)
                        case .failure:
                            self?.showAlertForLeaveGroup(false)
                        }
                    }
                })
            ]
        )
    }

    // Clear-chat is UI-level; we accept a closure to run the UI’s clear action.
    func makeConfirmClearChatAlert(onConfirm: @escaping () -> Void) -> AlertViewModel {
        AlertViewModel(
            title: "Clear Chat?",
            subTitle: "This will remove messages from this device (others won’t be affected).",
            imageName: "warning",
            actions: [
                AlertActionModel(title: "Cancel", style: .secondary, action: { [weak self] in
                    self?.alertModel = nil
                }),
                AlertActionModel(title: "Clear", style: .destructive, action: { [weak self] in
                    self?.alertModel = nil
                    onConfirm()
                    self?.showAlertForClearChat()
                })
            ]
        )
    }
}
