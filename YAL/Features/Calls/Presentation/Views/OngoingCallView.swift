//
//  OngoingCallView.swift
//  YAL
//
//  Created by Pavithra MH on 16/10/25.
//

import SwiftUI
import LiveKit
// MARK: - OngoingCallView
struct OngoingCallView: View {
    @ObservedObject var viewModel: CallViewModel
    var roomModel: RoomModel
    var onMenuTap: (Participant) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            audioCallView
        }
    }
}

// MARK: - AUDIO CALL VIEW
extension OngoingCallView {
    
    private var audioCallView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
//                
//                headerView
//                    .padding(.top, 40)
//                Spacer(minLength: 0)
                
                if viewModel.isConnected {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(
                            columns: audioGridColumns(for: viewModel.allParticipants.count, geometry: geometry),
                            spacing: 16
                        ) {
                            ForEach(viewModel.allParticipants, id: \.sid) { participant in
                                ParticipantTile(
                                    contact: participant,
                                    roomModel: roomModel,
                                    onMenuTap: { onMenuTap(participant) }
                                )
                                .frame(
                                    height: audioTileHeight(
                                        for: viewModel.allParticipants.count,
                                        geometry: geometry
                                    )
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                
                if viewModel.isConnected {
                    controlButtons
                        .padding(.bottom, 12)
                }
            }
            .background(audioGradient)
            .ignoresSafeArea()
        }
    }
}
// MARK: - BACKGROUND GRADIENT
extension OngoingCallView {
    private var audioGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 3/255, green: 27/255, blue: 74/255),
                Color(red: 13/255, green: 43/255, blue: 84/255),
                Color.black
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - HEADER
extension OngoingCallView {
    private var headerView: some View {
        HStack {
            Button(action: {
                NotificationCenter.default.post(name: .dismissCallView, object: nil)
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
            
            VStack(alignment: .center) {
                Text(CallManager.shared.currentRoomModel?.name ?? "")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal)
    }
}

// MARK: - CONTROL BUTTONS
extension OngoingCallView {
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            
            controlButton(icon: viewModel.isMuted ? "mic.slash.fill" : "mic.fill") {
                viewModel.toggleMute()
            }
            
            controlButton(icon: CallManager.shared.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1") {
                viewModel.toggleSpeaker()
            }
            
            Button(action: viewModel.disconnect) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 60, height: 60)
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
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: icon).foregroundColor(.black))
        }
    }
}

// MARK: - GRID & LAYOUT UTILS
extension OngoingCallView {
    
    private func audioGridColumns(for count: Int, geometry: GeometryProxy) -> [GridItem] {
        switch count {
            case 0...2:
                return [GridItem(.flexible())]
            case 3...4:
                return Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
            default:
                return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        }
    }
    
    private func audioTileHeight(for count: Int, geometry: GeometryProxy) -> CGFloat {
        let total = geometry.size.height
        switch count {
            case 1: return total * 0.5
            case 2: return total * 0.3
            case 3...4: return total * 0.28
            default: return total * 0.22
        }
    }
}

// MARK: - OngoingCallView
struct ParticipantTile: View {
    let contact: Participant
    let roomModel: RoomModel
    let isActive: Bool = false
    let onMenuTap: () -> Void
    
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        ZStack() {
            // CARD BACKGROUND
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.85))
                )
            VStack(spacing: 8) {
                // NAME
                Text(displayName)
                    .foregroundColor(.black)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 10)
                
                // AVATAR + MUTE ICON
                ZStack(alignment: .bottom) {
                    if contact.isCameraEnabled(),
                       let videoTrack = contact.videoTracks.first?.track as? VideoTrack{
                        LiveKitVideoView(track: videoTrack)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(width: 180, height: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isActive ? Color.green.opacity(0.8) : .clear, lineWidth: 2)
                            )
                    } else {
                        avatarView
                    }
                    
                    // Mic overlay bottom center
                    if contact.isMicrophoneEnabled() {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(y: 4)
                    } else {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.5))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(y: 4)
                    }
                }
                .frame(height: 100)
                
                Spacer()
            }
            .padding(.horizontal, 0)
            
            // Top-right ellipsis button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onMenuTap) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(0)) // horizontal
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(10)
                }
                Spacer()
            }
            
        }
        .frame(height: 180)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(contact.isSpeaking ? Color.green : .clear, lineWidth: 2)
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
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
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
