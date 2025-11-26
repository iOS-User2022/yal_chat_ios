//
//  LoadingViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 21/04/25.
//

import SwiftUI
import Combine

final class LoadingViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var isComplete: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let repo: ChatRepository

    init(repo: ChatRepository) {
        self.repo = repo
    }

    func start() {
    }
}
