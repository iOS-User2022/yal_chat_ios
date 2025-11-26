//
//  EnvironmentManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 19/09/25.
//


import Combine
import UIKit

protocol EnvironmentProviding {
    var baseURL: URL { get }
    var configPublisher: AnyPublisher<EnvironmentConfig, Never> { get }
}

final class EnvironmentManager: ObservableObject, EnvironmentProviding {
    @Published private(set) var config: EnvironmentConfig = .fromDefaults()
    private var cancelables = Set<AnyCancellable>()
    var onChange: ((EnvironmentConfig, EnvironmentConfig) -> Void)?
    
    var baseURL: URL { config.baseURL }
    var configPublisher: AnyPublisher<EnvironmentConfig, Never> { $config.eraseToAnyPublisher() }

    func refresh() {
        let old = config
        let new = EnvironmentConfig.fromDefaults()
        // compare explicitly so we don't require Equatable conformance
        guard old.env != new.env || old.baseURL != new.baseURL || old.pushBaseURL != new.pushBaseURL else { return }
        config = new
        onChange?(old, new)
    }

    init(center: NotificationCenter = .default) {
        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancelables)
    }
}
