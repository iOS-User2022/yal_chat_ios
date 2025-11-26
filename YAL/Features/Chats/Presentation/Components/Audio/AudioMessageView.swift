//
//  AudioMessageView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct AudioMessageView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let message: ChatMessageModel
    let onPlay: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Button(action: onPlay) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                    if !editing {
                        audioPlayer.seek(to: audioPlayer.currentTime)
                    }
                }
            }
            
            HStack {
                ForEach([1.0, 1.5, 2.0], id: \.self) { rate in
                    Button(action: {
                        audioPlayer.setPlaybackRate(Float(rate))
                    }) {
                        Text("\(rate, specifier: "%.1f")x")
                            .font(.caption)
                            .foregroundColor(audioPlayer.playbackRate == Float(rate) ? .blue : .primary)
                    }
                }
            }
        }
        .onAppear {
            audioPlayer.onPlaybackEnd = {
                // Reset to initial state
            }
        }
    }
}
