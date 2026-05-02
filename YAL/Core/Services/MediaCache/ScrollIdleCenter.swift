//
//  ScrollIdleCenter.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/12/25.
//


import Foundation
import Combine

/// Emits `true` after the user stops dragging the message list and stays idle for ≥ 1s.
final class ScrollIdleCenter: ObservableObject {
    static let shared = ScrollIdleCenter()
    private let dragging = CurrentValueSubject<Bool, Never>(false)

    /// `true` when idle (not dragging) and stable for ≥1s.
    var idlePublisher: AnyPublisher<Bool, Never> {
        dragging
            .map { !$0 } // not dragging → candidate idle
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func setDragging(_ isDragging: Bool) {
        dragging.send(isDragging)
    }
}