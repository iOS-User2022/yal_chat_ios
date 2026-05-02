//
//  OutGoingCallView.swift
//  YAL
//
//  Created by Pavithra MH on 16/10/25.
//
import SwiftUI
import LiveKit

struct OutgoingCallView: View {
    @ObservedObject var viewModel: CallViewModel
    let participants: [ContactModel]?
    @Environment(\.dismiss) private var dismiss
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Profile Images + Name
            ZStack {
                // Left Profile Image
                AvatarBubble(
                    url: CallManager.shared.currentRoomModel?.participants.first?.avatarURL ?? nil,
                    size: 140
                )
                .offset(x: (CallManager.shared.currentRoomModel?.participants.count ?? 0) > 2 ? -35 : 0)
                
                if (CallManager.shared.currentRoomModel?.participants.count ?? 0) > 2 {

                    AvatarBubble(
                        url: CallManager.shared.currentRoomModel?.participants.last?.avatarURL ?? nil,
                        size: 140
                    )
                    .overlay(
                        ZStack {
//                            Circle().fill(Color.black.opacity(0.4))
                            Text("+\((CallManager.shared.currentRoomModel?.participants.count ?? 3) - 2)")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    )
                    .offset(x: 35)
                }
            }
            .padding(30)
            
            // MARK: Names
            VStack(spacing: 6) {
                Text("YAL call")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                Text(getName())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
            }
            if (viewModel.isConnected){
                VStack(spacing: 10) {
                    Text("Ringing...")
                        .font(.headline)
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }else{
                VStack(spacing: 10) {
                    Text("Calling...")
                        .font(.headline)
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
            Spacer()
            
            // MARK: Control Bar
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
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(height: 60)
            .padding(10)
            .background(Color.white.opacity(0.6))
            .cornerRadius(20)
            .shadow(radius: 5)
        }
        .background(Color.clear.ignoresSafeArea())
        .padding(.top, 10)
    }
    
    // MARK: - Reusable Helpers
    private func backButton() -> some View {
        Button(action: {
            NotificationCenter.default.post(name: .dismissCallView, object: nil)
        }) {
            Image("backArrow")
                .foregroundColor(.white)
                .font(.title2)
                .padding(10)
        }
    }
    
    private func getName() -> String {
        if CallManager.shared.currentRoomModel?.participants.count ?? 0 > 2 {
            var text = CallManager.shared.currentRoomModel?.participants.count ?? 0 > 2 ? " & Others" : ""
            
            let firstName = CallManager.shared.currentRoomModel?.participants.first(where: { participant in
                if let name = participant.displayName {
                    return !name.isEmpty
                }
                return false
            })?.displayName
            
            if firstName?.isEmpty != nil {
                return (firstName ?? "") + text
            }else{
                return (CallManager.shared.currentRoomModel?.participants.first?.phoneNumber ?? "") + text
            }
        }else{
            if let val = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)?.userId {
                
                let participant = CallManager.shared.currentRoomModel?.participants.first(where: { $0.id != val})
                if participant?.displayName?.isEmpty ?? true {
                    return participant?.phoneNumber ?? ""
                }else{
                    return participant?.displayName ?? ""
                }
            }
        }
        return ""
    }
    
    private func avatarImage(for nameOrURL: String) -> some View {
        Group {
            if let url = URL(string: nameOrURL), nameOrURL.hasPrefix("http") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().clipShape(Circle())
                    } else {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                }
            } else {
                Image(nameOrURL)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            }
        }
    }
    
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.title3)
                )
        }
    }

}

struct AvatarBubble: View {
    let url: String?
    let size: CGFloat
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.largeTitle)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear { loadImage() }
    }
    
    private func loadImage() {
        guard image == nil, let url = url else { return }
        
        MediaCacheManager.shared.getMedia(
            url: url,
            type: .image,
            progressHandler: { _ in },
            completion: { result in
                switch result {
                    case .success(let filePath):
                        let finalURL = filePath.hasPrefix("file://") ?
                        URL(string: filePath)! :
                        URL(fileURLWithPath: filePath)
                        
                        if let uiImage = UIImage(contentsOfFile: finalURL.path) {
                            DispatchQueue.main.async {
                                self.image = uiImage.preparingForDisplay() ?? uiImage
                            }
                        }
                        
                    case .failure(let err):
                        print("Avatar load error:", err)
                }
            }
        )
    }
}
