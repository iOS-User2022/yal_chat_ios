//
//  OngoingVideoView.swift
//  YAL
//
//  Created by Pavithra MH on 25/11/25.
//


import SwiftUI
import LiveKit
// MARK: - OngoingCallView
struct OngoingVideoView: View {
    @ObservedObject var viewModel: CallViewModel
    var roomModel: RoomModel
    var onMenuTap: (Participant) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            videoCallView
        }
    }
}

// MARK: - VIDEO CALL VIEW
extension OngoingVideoView {
    
    private var videoCallView: some View {
        GeometryReader { geometry in
            ZStack {
                mainVideoLayout(geometry: geometry)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
                    .clipped()
                
                VStack {
                    headerView
                        .padding(.top, 30)
                    
                    Spacer()
                    
                    if viewModel.isConnected {
                        controlButtons
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 30, trailing: 10))
                    }
                }
                .padding(.horizontal)
            }
//            .ignoresSafeArea()
            .padding(EdgeInsets(top: 30, leading: 0, bottom: 30, trailing: 0))

        }
    }
    
    
    // MARK: Layout Decision Logic
    @ViewBuilder
    private func mainVideoLayout(geometry: GeometryProxy) -> some View {
        
        let participants = viewModel.allParticipants
        
        switch participants.count {
                
            case 0:
                Color.black
                
            case 1:
                singleParticipantVideo(participants[0], geometry)
                
            case 2:
                twoParticipantsVertical(participants, geometry)
                
            default:
                multiParticipantGrid(participants, geometry)
        }
    }
    
    // MARK: SINGLE VIDEO (FULLSCREEN)
    private func singleParticipantVideo(_ p: Participant, _ geometry: GeometryProxy) -> some View {
        VideoParticipantTile(
            contact: p,
            roomModel: roomModel,
            onMenuTap: { onMenuTap(p) },
            count: 1,
            geometry: geometry
        )
        .frame(
            width: geometry.size.width,
            height: geometry.size.height
        )
        .clipped()
    }
    
    // MARK: TWO VIDEOS — VERTICAL STACK
    private func twoParticipantsVertical(_ list: [Participant], _ geometry: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            ForEach(list, id: \.sid) { p in
                VideoParticipantTile(
                    contact: p,
                    roomModel: roomModel,
                    onMenuTap: { onMenuTap(p) },
                    count: 2,
                    geometry: geometry
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height * 0.5
                )
                .clipped()
            }
        }
        .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
    }
    
    // MARK: MULTIPLE VIDEOS GRID (SCROLLABLE)
    private func multiParticipantGrid(_ list: [Participant], _ geometry: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: videoGridColumns(for: list.count, geometry: geometry),
                spacing: 4
            ) {
                ForEach(list, id: \.sid) { p in
                    VideoParticipantTile(
                        contact: p,
                        roomModel: roomModel,
                        onMenuTap: { onMenuTap(p) },
                        count: list.count,
                        geometry: geometry
                    )
                    .frame(
                        width: videoTileWidth(for: list.count, geometry: geometry),
                        height: videoTileHeight(for: list.count, geometry: geometry)
                    )
                    .clipped()
                }
            }
            .padding(.horizontal, 4)
            .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
        }
    }
}

// MARK: - HEADER
extension OngoingVideoView {
    private var headerView: some View {
        HStack {
            Button(action: {
                CallManager.shared.hideCallView()
            }) {
                Image("backArrow")
                    .foregroundColor(.white)
                    .padding(10)
            }
            
            Spacer()
            
            VStack(alignment: .center) {
                Text("Ongoing call")
                    .foregroundColor(.white)
                    .font(.headline)
                Text("End-to-end encrypted")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            Spacer()
            Button {
                if PiPManager.shared.isActive {
                    PiPManager.shared.stop()
                } else {
                    PiPManager.shared.start()
                }
            } label: {
                Image(systemName: "pip")
                    .foregroundColor(.white)
            }
            Spacer()

        }
        .padding(.top, 12)
        .padding(.horizontal)
    }
}

// MARK: - CONTROL BUTTONS
extension OngoingVideoView {
    
    private var controlButtons: some View {
        HStack(spacing: 15) {
            
            controlButton(icon: viewModel.isMuted ? "mic.slash.fill" : "mic.fill") {
                viewModel.toggleMute()
            }
            
            controlButton(icon: viewModel.isCameraOn ? "video.fill" : "video.slash.fill") {
                Task {
                    await viewModel.toggleCamera()
                }
            }
            
            controlButton(icon: CallManager.shared.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1") {
                viewModel.toggleSpeaker()
            }
            
            controlButton(icon: viewModel.isFrontCamera ? "camera.fill" : "camera.rotate") {
                Task {
                    await viewModel.toggleCameraFrontBack()
                }
            }
            
            Button(action: viewModel.disconnect) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "phone.down.fill").foregroundColor(.white))
            }
        }
        .frame(height: 60)
        .padding(10)
        .background(Color.white.opacity(0.6))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: icon).foregroundColor(.black))
        }
    }
}

// MARK: - GRID & LAYOUT UTILS
extension OngoingVideoView {
    
    private func videoGridColumns(for count: Int, geometry: GeometryProxy) -> [GridItem] {
        switch count {
            case 1:
                return [GridItem(.flexible())]
            case 2:
                return [GridItem(.flexible()), GridItem(.flexible())]
            case 3, 4:
                return Array(repeating: GridItem(.flexible()), count: 2)
            default:
                return geometry.size.width > 380 ?
                Array(repeating: GridItem(.flexible()), count: 3)
                : Array(repeating: GridItem(.flexible()), count: 2)
        }
    }
    
    private func videoTileWidth(for count: Int, geometry: GeometryProxy) -> CGFloat {
        let width = geometry.size.width - 10
        switch count {
            case 1: return width
            case 2: return width / 2 - 6
            case 3, 4: return width / 2 - 6
            default: return width / 3 - 6
        }
    }
    
    private func videoTileHeight(for count: Int, geometry: GeometryProxy) -> CGFloat {
        let height = geometry.size.height
        switch count {
            case 1: return height
            case 2: return height * 0.5
            case 3, 4: return height * 0.4
            default: return height * 0.4
        }
    }
}

struct VideoParticipantTile: View {
    let contact: Participant
    let roomModel: RoomModel
    let isActive: Bool = false
    let onMenuTap: () -> Void
    let count: Int
    let geometry: GeometryProxy
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.clear
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if contact.isCameraEnabled(),
                   let videoTrack = contact.videoTracks.first?.track as? VideoTrack {
                    LiveKitVideoView(track: videoTrack)
                        .scaledToFill()
                        .clipped()
                } else {
                    avatarView
                        .frame(width: 100, height: 100)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(16)
        )
        .overlay(
            VStack() {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: contact.isMicrophoneEnabled() ? "mic.fill" : "mic.slash.fill")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                    
                    Text(displayName)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.bottom, 10)
            }
        )
        .overlay(
            /// TOP RIGHT MENU
            VStack {
                HStack {
                    Spacer()
                    Button(action: onMenuTap) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .padding(10)
                }
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(contact.isSpeaking ? Color.green : Color.black, lineWidth: 4)
        )
    }
    
    
    private var displayName: String {
        
        if let name = contact.name {
            return name
        } else if let id = contact.identity?.stringValue,
                  let participant = roomModel.participants.first(where: { $0.userId == id }) {
            return participant.fullName ?? participant.phoneNumber
        }
        return ""
    }
    
    // MARK: - Avatar view
    private var avatarView: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            guard downloadedImage == nil else { return }
            if let matched = roomModel.participants.first(where: { $0.userId == contact.identity?.stringValue }) {
                print("Found participant:", matched.fullName)
            }
            if let matched = roomModel.participants.first(where: { $0.userId == contact.identity?.stringValue }), (matched.avatarURL != nil) {
                MediaCacheManager.shared.getMedia(
                    url: matched.avatarURL ?? "",
                    type: .image,
                    progressHandler: { progress in
                        downloadProgress = progress
                    },
                    completion: { result in
                        switch result {
                            case .success(let imagePath):
                                let fileURL = imagePath.hasPrefix("file://")
                                ? URL(string: imagePath)!
                                : URL(fileURLWithPath: imagePath)
                                if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                                    DispatchQueue.main.async {
                                        downloadedImage = uiImage.preparingForDisplay() ?? uiImage
                                    }
                                }
                            case .failure(let error):
                                print("Failed to download media: \(error)")
                        }
                    }
                )
            }
        }
    }
}
