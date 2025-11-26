//
//  FirstFrameTriggerHelper.swift
//  YAL
//
//  Created by Vishal Bhadade on 07/09/25.
//

import SwiftUI
import Combine

/// Fires its closure on the *next* display frame after the view appears.
/// Guarantees at least one frame was rendered before firing.
struct OnFirstFrame: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.background(FirstFrameTrigger(action: action))
    }
}

extension View {
    func onFirstFrame(_ action: @escaping () -> Void) -> some View {
        modifier(OnFirstFrame(action: action))
    }
}

private struct FirstFrameTrigger: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> _FirstFrameView {
        let v = _FirstFrameView()
        v.action = action
        return v
    }
    func updateUIView(_ uiView: _FirstFrameView, context: Context) {}
}

private final class _FirstFrameView: UIView {
    var action: (() -> Void)?
    private var link: CADisplayLink?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, link == nil else { return }
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }

    @objc private func tick() {
        link?.invalidate(); link = nil
        action?(); action = nil
    }
}
