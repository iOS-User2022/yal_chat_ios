//
//  RecordingView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct RecordingView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var isPaused = false
    @State private var isMerging = false
    
    var onSend: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(timeString(from: audioPlayer.isPlaying ? audioPlayer.currentTime : audioRecorder.elapsedTime))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                
                WaveformView(amplitudes: audioRecorder.amplitudes)
                    .frame(height: 10)
                    .padding(.horizontal, 10)
                
                if isPaused {
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            isMerging = true
                            audioRecorder.mergeRecordings { mergedURL in
                                isMerging = false
                                if let url = mergedURL {
                                    audioPlayer.play(url: url)
                                }
                            }
                        }
                    }) {
                        if isMerging {
                            ProgressView()
                        } else {
                            Image(audioPlayer.isPlaying ? "black_pause" : "black_play")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                    }
                    .disabled(isMerging)
                }
            }
            .padding(.horizontal)
            
            HStack {
                Button(action: onCancel) {
                    Image("deleteButton")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                
                Spacer()
                
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.pauseRecording()
                        isPaused = true
                    } else {
                        audioRecorder.resumeRecording()
                        isPaused = false
                    }
                }) {
                    Image(audioRecorder.isRecording ? "fill_pause" :
                            audioPlayer.isPlaying ? "cross_mic" : "fill_mic")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                .disabled(audioPlayer.isPlaying)
                
                Spacer()
                
                Button(action: {
                    // Ensure recording is stopped before sending
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    }
                    onSend()
                }) {
                    Image("send")
                        .resizable()
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .mask(
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .frame(height: 20)
                        Rectangle()
                    }
                )
        )
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
