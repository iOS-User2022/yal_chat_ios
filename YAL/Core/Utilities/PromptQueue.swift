//
//  PromptQueue.swift
//  YAL
//
//  Created by Vishal Bhadade on 27/09/25.
//

import Foundation

// Runs UI prompts one at a time. Each enqueued presenter must call `done()` when dismissed.
enum PromptQueue {
    private static var isShowing = false
    private static var q: [(@escaping () -> Void) -> Void] = []

    static func enqueue(_ present: @escaping (@escaping () -> Void) -> Void) {
        DispatchQueue.main.async {
            if isShowing {
                q.append(present)
            } else {
                isShowing = true
                present { finish() }
            }
        }
    }

    private static func finish() {
        DispatchQueue.main.async {
            if let next = q.first {
                q.removeFirst()
                next { finish() }
            } else {
                isShowing = false
            }
        }
    }
}
