//
//  TokenProvider.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Combine

protocol TokenProvider {
    var accessToken: String? { get }
    var matrixToken: String? { get }
    func setToken(_ token: String)
    func clear()
    
    var accessTokenPublisher: AnyPublisher<String?, Never> { get }
    var matrixTokenPublisher: AnyPublisher<String?, Never> { get }
    var logoutPublisher: AnyPublisher<Void, Never> { get }
}
