//
//  SplashVideoPlayer.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import SwiftUI
import AVKit

struct SplashVideoPlayer: UIViewRepresentable {
    var onFinish: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        guard let url = Bundle.main.url(forResource: "My_Movie", withExtension: "mp4") else {
            return view
        }

        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)

        context.coordinator.bindPlayer(player, onFinish: onFinish)
        player.play()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        private var playerObserver: Any?

        func bindPlayer(_ player: AVPlayer, onFinish: @escaping () -> Void) {
            playerObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                onFinish()
            }
        }

        deinit {
            if let observer = playerObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
