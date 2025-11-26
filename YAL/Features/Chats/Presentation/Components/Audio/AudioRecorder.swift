//
//  AudioRecorder.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var hasRecording = false
    @Published var amplitudes: [CGFloat] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioFileURL: URL?
    private var displayLink: CADisplayLink?
    private var recordingSegments: [URL] = []
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            guard let url = audioFileURL else { return }
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            startTimer()
            startDisplayLink()
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        if let url = audioFileURL {
            if FileManager.default.fileExists(atPath: url.path) {
                recordingSegments.append(url)
            }
        }
        isRecording = false
        hasRecording = !recordingSegments.isEmpty
        stopTimer()
        stopDisplayLink()
        audioRecorder = nil
    }
    
    func getRecordedAudioURL() -> URL? {
        return recordingSegments.last
    }
    
    func pauseRecording() {
        audioRecorder?.stop()
        if let url = audioFileURL {
            recordingSegments.append(url)
        }
        isRecording = false
        stopTimer()
        stopDisplayLink()
        audioRecorder = nil
    }
    
    func resumeRecording() {
        startRecording()
    }

    func reset() {
        stopRecording()
        audioPlayer?.stop()
        
        // Clean up segment files
        for url in recordingSegments {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingSegments.removeAll()
        amplitudes.removeAll()
        elapsedTime = 0
        hasRecording = false
        audioFileURL = nil
        isRecording = false
        isPlaying = false
    }

    func mergeRecordings(completion: @escaping (URL?) -> Void) {
        let composition = AVMutableComposition()
        var insertTime = CMTime.zero

        for segmentURL in recordingSegments {
            let asset = AVURLAsset(url: segmentURL)
            do {
                if let track = asset.tracks(withMediaType: .audio).first {
                    try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    let compositionTrack = composition.tracks(withMediaType: .audio).last!
                    try compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: track, at: insertTime)
                    insertTime = insertTime + asset.duration
                }
            } catch {
                print("Failed to merge segment: \(error)")
                completion(nil)
                return
            }
        }

        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil)
            return
        }
        
        exporter.outputURL = exportURL
        exporter.outputFileType = .m4a
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(exportURL)
                } else {
                    print("Failed to export merged audio: \(exporter.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                }
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateAmplitudes))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateAmplitudes() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let amplitude = CGFloat(max(0, 1 + power / 30))
        amplitudes.append(amplitude)
        if amplitudes.count > 50 {
            amplitudes.removeFirst()
        }
    }
    
    func playRecording() {
        guard let url = audioFileURL, hasRecording else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Could not play recording: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
