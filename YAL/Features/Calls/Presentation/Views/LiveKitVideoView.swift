//
//  LiveKitVideoView.swift
//  YAL
//
//  Created by Pavithra MH on 24/10/25.
//

import SwiftUI
import LiveKit
import AVFoundation
import AVKit

struct LiveKitVideoView: UIViewRepresentable {
    let track: VideoTrack
    
    func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.track = track
        view.layoutMode = .fill       // `.fit` = full frame, `.fill` = crop to fill
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        
        CallViewModel.shared.register(videoView: view)

        return view
    }
    
    func updateUIView(_ uiView: VideoView, context: Context) {
        uiView.track = track
    }
}


//struct LiveKitVideoViewRepresentable: UIViewRepresentable {
//    @ObservedObject var viewModel: CallViewModel
//    let showControls: Bool // optional flag if you want overlay controls
//    
//    func makeCoordinator() -> Coordinator { Coordinator(self) }
//    
//    func makeUIView(context: Context) -> UIView {
//        // Use LiveKit's VideoView (UIKit)
//        let container = UIView(frame: .zero)
//        container.backgroundColor = .black
//        
//        let videoView = VideoView(frame: .zero)
//        videoView.translatesAutoresizingMaskIntoConstraints = false
//        videoView.contentMode = .scaleAspectFill
//        
//        container.addSubview(videoView)
//        NSLayoutConstraint.activate([
//            videoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
//            videoView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
//            videoView.topAnchor.constraint(equalTo: container.topAnchor),
//            videoView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
//        ])
//        
//        viewModel.register(videoView: videoView)
//        
//        if let layer = videoView.avSampleBufferDisplayLayer {
//            // Make sure layer is ready before calling setup
//            PiPManager.shared.setup(layer: layer)
//        }
//        
//        return container
//    }
//    
//    func updateUIView(_ uiView: UIView, context: Context) {
//        // If local track becomes available after create, ensure the viewModel re-attaches
//        if let videoView = uiView.subviews.compactMap({ $0 as? VideoView }).first {
//            viewModel.register(videoView: videoView)
//        }
//    }
//    
//    // Coordinator in case you want to handle delegate callbacks later
//    class Coordinator {
//        var parent: LiveKitVideoViewRepresentable
//        init(_ parent: LiveKitVideoViewRepresentable) { self.parent = parent }
//    }
//}
