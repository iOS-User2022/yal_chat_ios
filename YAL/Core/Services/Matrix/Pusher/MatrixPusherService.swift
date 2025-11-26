//
//  MatrixPusherService.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Combine
import Foundation

final class MatrixPusherService {
    private let matrixPusherRepository: PushRegistrationRepositoryProtocol

    init(matrixPusherRepository: PushRegistrationRepositoryProtocol) {
        self.matrixPusherRepository = matrixPusherRepository
    }

    // Register/replace an HTTP pusher (Matrix CS API v3).
    func setPusher(
        deviceToken: String
    ) -> AnyPublisher<Void, Error> {
        return matrixPusherRepository.registerPusher(deviceTokenHex: deviceToken)
    }

    // Delete a pusher via the dedicated endpoint (alt to kind:nil).
    func deletePusher(
        deviceToken: String
    ) -> AnyPublisher<Void, Error> {
        return matrixPusherRepository.unregisterPusher(deviceTokenHex: deviceToken)
    }
}
