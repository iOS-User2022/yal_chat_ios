//
//  UserProfileViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 12/06/25.
//


import Combine
import Foundation

final class UserProfileViewModel: ObservableObject {
    private let roomService: RoomServiceProtocol
    let user: ContactModel
    let currentRoom: RoomModel

    @Published var sharedGroups: [RoomModel] = []
    private var cancellables = Set<AnyCancellable>()
    @Published var isFavorite: Bool = false

    init(user: ContactModel, currentRoom: RoomModel, roomService: RoomServiceProtocol) {
        self.user = user
        self.currentRoom = currentRoom
        self.roomService = roomService
        self.isFavorite = roomService.getFavoriteRooms().contains(where: { $0.isEmpty ? false : $0 == currentRoom.id })

        fetchCommonGroups()
    }

    func fetchCommonGroups() {
        guard let userId = user.userId else {
            return
        }
        roomService.getCommonGroups(with: userId)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch shared groups: \(error)")
                }
            } receiveValue: { [weak self] rooms in
                self?.sharedGroups = rooms
            }
            .store(in: &cancellables)
    }

    var userDetails: ContactModel? {
        roomDetails.opponent
    }

    var roomDetails: RoomModel {
        currentRoom
    }
    
    func toggeleFavorite(for room: RoomModel) {
        roomService.toggleFavoriteRoom(roomID: room.id)
        self.isFavorite = roomService.getFavoriteRooms().contains(where: { $0.isEmpty ? false : $0 == room.id })
    }
}
