//
//  PushRegistrationRepositoryProtocol.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Combine

public protocol PushRegistrationRepositoryProtocol {
    func registerPusher(deviceTokenHex: String) -> AnyPublisher<Void, Error>
    func unregisterPusher(deviceTokenHex: String) -> AnyPublisher<Void, Error>
}
