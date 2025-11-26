//
//  NotificationRouter.swift
//  YAL
//
//  Created by Sheetal Jha on 15/10/25.
//

import Foundation
import Combine

/// Handles routing logic for push notifications
final class NotificationRouter {
    
    // MARK: - Fetch Room
    
    /// Fetch RoomModel from roomId
    /// Returns publisher that emits RoomModel or nil if not found
    static func fetchRoom(
        roomId: String,
        chatRepository: ChatRepositoryProtocol
    ) -> AnyPublisher<RoomSummaryModel?, Never> {
        
        // Check if room already exists in cache
        if let existingRoom = chatRepository.getExistingRoomSummaryModel(roomId: roomId) {
            
            return Just(existingRoom).eraseToAnyPublisher()
        }
        
        // Room not in cache, fetch from server
        return chatRepository.getStateEvents(forRoom: roomId)
            .map { events -> RoomSummaryModel? in
                guard let (room, _) = chatRepository.getRoomSummaryModel(roomId: roomId, events: events) else {
                    return nil
                }
                return room
            }
            .catch { _ -> Just<RoomSummaryModel?> in
                return Just(nil)
            }
            .eraseToAnyPublisher()
    }
    
}

