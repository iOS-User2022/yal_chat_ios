//
//  PIPService.swift
//  YAL
//
//  Created by Pavithra MH on 02/12/25.
//
import AVKit
import UIKit

final class PiPManager: NSObject {
    static let shared = PiPManager()
    
    private var pipController: AVPictureInPictureController?
    private var pipLayer: AVSampleBufferDisplayLayer?
    
    private override init() {
        super.init()
    }
    
    func setup(layer: AVSampleBufferDisplayLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("❌ PiP not supported on this device")
            return
        }
        
        // Avoid recreating
        if pipLayer === layer { return }
        
        pipLayer = layer
        
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: layer,
            playbackDelegate: self
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        
        print("✅ PiP configured")
    }
    
    func start() {
        guard let pip = pipController, !pip.isPictureInPictureActive else { return }
        pip.startPictureInPicture()
        print("▶️ PiP started")
    }
    
    func stop() {
        guard let pip = pipController, pip.isPictureInPictureActive else { return }
        pip.stopPictureInPicture()
        print("⏹ PiP stopped")
    }
    
    var isActive: Bool {
        pipController?.isPictureInPictureActive == true
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("📺 PiP did start")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("📺 PiP did stop")
    }
}

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {
        
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange { .invalid }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }
}
