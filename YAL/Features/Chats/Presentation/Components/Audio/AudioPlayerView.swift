//
//  AudioPlayerView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct AudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    let audioURL: URL
    
    var body: some View {
        HStack {
            Button(action: {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play(url: audioURL)
                }
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
            
            Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                if !editing {
                    audioPlayer.seek(to: audioPlayer.currentTime)
                }
            }
            .accentColor(.black)
            
            Text(timeString(from: audioPlayer.currentTime))
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(15)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
