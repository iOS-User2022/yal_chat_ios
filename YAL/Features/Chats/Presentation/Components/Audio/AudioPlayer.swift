//
//  AudioPlayer.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: AnyCancellable?
    var onPlaybackEnd: (() -> Void)?
    
    func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            duration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Could not play audio: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        stopTimer()
        audioPlayer = nil
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }

    func setPlaybackRate(_ rate: Float) {
        guard let player = audioPlayer, player.isPlaying else { return }
        self.playbackRate = rate
        player.rate = rate
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.currentTime = self?.audioPlayer?.currentTime ?? 0
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0
        onPlaybackEnd?()
    }
}
