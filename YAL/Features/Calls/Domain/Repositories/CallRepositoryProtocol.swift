//
//  CallRepositoryProtocol.swift
//  YAL
//
//  Created by Pavithra MH on 30/10/25.
//


import Foundation
import Combine

final class CallRepository {
    private let apiManager: ApiManageable
    
    init(apiManager: ApiManageable) {
        self.apiManager = apiManager
    }
    
    func getLKAccessToken(roomName: String, participantName: String, participantId:String, avatarUrl:String) -> AnyPublisher<APIResult<LKTokenResponse>, APIError> {
        apiManager.getLKAccessToken(roomName: roomName, participantName: participantName, participantId: participantId, avatarUrl:avatarUrl)
    }
    
}
