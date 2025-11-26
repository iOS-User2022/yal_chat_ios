//
//  RegisterPusherUseCase.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/09/25.
//


import Combine

public struct RegisterPusherUseCase {
    private let service: MatrixPusherService
    
    init(service: MatrixPusherService) {
        self.service = service
    }
    
    public func execute(deviceTokenHex: String) -> AnyPublisher<Void, Error> {
        service.setPusher(deviceToken: deviceTokenHex)
    }
}
