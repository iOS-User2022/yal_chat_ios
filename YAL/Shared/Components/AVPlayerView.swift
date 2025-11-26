//
//  AVPlayerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 19/05/25.
//

import AVKit
import SwiftUI

struct AVPlayerView: View {
    let player: AVPlayer
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.play()
            }
            .edgesIgnoringSafeArea(.all)
    }
}
