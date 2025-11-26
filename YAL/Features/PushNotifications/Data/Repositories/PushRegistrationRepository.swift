//
//  PushRegistrationRepository.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Combine

final class PushRegistrationRepository: PushRegistrationRepositoryProtocol {
    private let matrixAPIManager: MatrixAPIManagerProtocol
    private let tokenProvider: TokenProvider
    enum PushError: Error { case missingAccessToken }

    init(matrixAPIManager: MatrixAPIManagerProtocol,
         tokenProvider: TokenProvider
    ) {
        self.matrixAPIManager = matrixAPIManager
        self.tokenProvider = tokenProvider
    }

    func registerPusher(deviceTokenHex: String) -> AnyPublisher<Void, Error> {
        guard let base64Token = deviceTokenHex.base64FromHex else {
            return Fail(error: PushError.missingAccessToken).eraseToAnyPublisher()
        }
            
        let req = MatrixPusherSetRequest(
            kind: "http",
            appId: DeviceInfo.bundleIdentifier, // "com.echelonera.yalchat"
            pushkey: base64Token,
            appDisplayName: DeviceInfo.appDisplayName,
            deviceDisplayName: DeviceInfo.deviceDisplayName, // wrap UIDevice.current.name
            profileTag: "",
            lang: "en",
            data: .init(url: MatrixAPIEndpoints.pusherUrl.urlString()), // https://push.yal.chat/_matrix/push/v1/notify
            append: false
        )
        
        return matrixAPIManager.registerPusher(request: req)
    }

    func unregisterPusher(deviceTokenHex: String) -> AnyPublisher<Void, Error> {
        let request = MatrixPusherDeleteRequest(
            appId: DeviceInfo.bundleIdentifier,
            pushkey: deviceTokenHex
        )
        return matrixAPIManager.deletePusher(request: request)
    }
}
