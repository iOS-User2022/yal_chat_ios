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

    func kickOutUser(_ user: ContactModel) {
        roomService.kickUserFromRoom(room: room, user: user, reason: "")
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                if case .finished = completion {
                    print("Kicked \(user.userId ?? "") from \(self.room.id)")
                } else {
                    print("Failed to kick user \(user.userId ?? "")")
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func leaveRoom() {
        roomService.leaveRoom(room: room, reason: "")
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                if case .finished = completion {
                    print("Left room \(self.room.id)")
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func deleteRoom(completion: @escaping (Result<Void, APIError>) -> Void) {
        roomService.deleteRoom(room: room, reason: "Admin deleted the room")
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(receiveCompletion: { [weak self] completionResult in
                guard self != nil else { return }
                switch completionResult {
                case .finished:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func inviteUsers(users: [ContactLite]) {
        roomService.inviteUsersToRoom(room: room, users: users, reason: "Admin invited the user to the room")
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(receiveCompletion: { [weak self] completion in
                guard self != nil else { return }
                if case .failure(let error) = completion {
                    print("Some invites failed: \(error)")
                }
            }, receiveValue: { results in
                results.forEach { (user, result) in
                    switch result {
                    case .success:
                        print("Invited \(user.fullName)")
                    case .unsuccess(let error):
                        print("Failed to invite \(user.fullName): \(error)")
                    }
                }
            })
            .store(in: &cancellables)
    }

    func toggleFavorite() {
        roomService.toggleFavoriteRoom(roomID: room.id)
        isFavorite = roomService.getFavoriteRooms().contains { !$0.isEmpty && $0 == room.id }
    }

    func updateRoomName(to newName: String, completion: @escaping (Result<Void, APIError>) -> Void) {
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
                    completion(.success(()))
                case .failure(let error):
                    self.showAlertForGroupNameUpdate(success: false)
                    completion(.failure(error))
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
            .receive(on: DispatchQueue.global(qos: .utility))
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    print("Room image updated")
                case .failure(let error):
                    print("Failed to update image: \(error)")
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
}
