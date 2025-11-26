//
//  AuthSessionProvider.swift
//  YAL
//
//  Created by Vishal Bhadade on 25/04/25.
//

import Combine

protocol AuthSessionProvider {
    var session: AuthSession? { get }
    func save(session: AuthSession)
    func clear()
    
    // NEW: emits on login/restore/refresh/clear
    var sessionPublisher: AnyPublisher<AuthSession?, Never> { get }
}
