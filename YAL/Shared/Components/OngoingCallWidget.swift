//
//  OngoingCallWidget.swift
//  YAL
//
//  Created by Sheetal Jha on 01/10/25.
//

import SwiftUI

struct OngoingCallWidget: View {
    let participants: [ContactModel]
    let callType: String
    let callState: CallState?
    let onJoinCall: () -> Void
    
    private let maxVisibleParticipants = 5
    
    var body: some View {
        HStack(spacing: 10) {
            
            if CallManager.shared.callState == .ongoing || CallManager.shared.callState == .outgoing {
                Button(action: onJoinCall) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                Spacer()
                
                // Center text
                Text("call in-progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                // Right circular red button
                Button(action: onJoinCall) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }else{
                // Participant avatars
                participantAvatars
                
                // Call info
                Text(callInfoText)
                    .font(Design.Font.medium(10))
                    .foregroundColor(Design.Color.white)
                
                Spacer()
                
                // Join call button
                Button(action: onJoinCall) {
                    Text("Join call")
                        .font(Design.Font.semiBold(8))
                        .foregroundColor(Design.Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#20BE00"))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height:70)
        .background(Design.Color.appGradient)
        .cornerRadius(12)
    }
    
    private var callInfoText: String {
        let typeText = callType.capitalized
        
        guard let state = callState else {
            return "Ongoing \(typeText) Call"
        }
        
        switch state {
        case .incoming:
            return "Incoming \(typeText) Call"
        case .ongoing:
            return "Ongoing \(typeText) Call"
        case .outgoing:
            return "Outgoing \(typeText) Call"
        default:
            return "Ongoing \(typeText) Call"
        }
    }
    
    @ViewBuilder
    private var participantAvatars: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.prefix(maxVisibleParticipants).enumerated()), id: \.element.id) { index, participant in
                ParticipantAvatarView(participant: participant)
                    .zIndex(Double(index))
            }
            // Show "+X" if there are more participants
            if participants.count > maxVisibleParticipants {
                Text("+\(participants.count - maxVisibleParticipants)")
                    .font(Design.Font.bold(8))
                    .foregroundColor(Design.Color.white)
                    .frame(width: 20, height: 20)
                    .background(Design.Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
    }
    
}

struct ParticipantAvatarView: View {
    let participant: ContactModel
    @State private var downloadedImage: UIImage?
    
    var body: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            } else if let imageData = participant.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            } else {
                Text(getInitials(from: participant.fullName ?? participant.phoneNumber))
                    .font(Design.Font.bold(8))
                    .foregroundColor(Design.Color.white)
                    .frame(width: 20, height: 20)
                    .background(participant.randomeProfileColor)
                    .clipShape(Circle())
            }
        }
        .onAppear {
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        guard downloadedImage == nil else { return }
        if let avatarUrl = participant.avatarURL, !avatarUrl.isEmpty {
            MediaCacheManager.shared.getMedia(
                url: avatarUrl,
                type: .image,
                progressHandler: { _ in },
                completion: { result in
                    switch result {
                    case .success(let imagePath):
                        let fileURL: URL = imagePath.hasPrefix("file://") 
                            ? URL(string: imagePath)! 
                            : URL(fileURLWithPath: imagePath)
                        
                        if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                            guard let data = try? Data(contentsOf: fileURL) else { return nil }
                            return UIImage(data: data)
                        }() {
                            DispatchQueue.main.async {
                                downloadedImage = uiImage
                            }
                        }
                    case .failure(_):
                        // Avatar loading failed, will show initials instead
                        break
                    }
                }
            )
        }
    }
}
//
//// MARK: - Preview
//struct OngoingCallWidget_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 20) {
//            OngoingCallWidget(
//                participants: [
//                    ContactModel(phoneNumber: "1234567890", userId: "1", fullName: "John Doe"),
//                    ContactModel(phoneNumber: "0987654321", userId: "2", fullName: "Jane Smith"),
//                    ContactModel(phoneNumber: "1111111111", userId: "3", fullName: "Bob Wilson")
//                ],
//                callType: "voice", callState: .end,
//                onJoinCall: {}
//            )
//        }
//        .padding()
//        .background(Color.gray.opacity(0.1))
//    }
//}
