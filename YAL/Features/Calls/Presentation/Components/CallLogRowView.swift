//
//  CallLogRowView.swift
//  YAL
//
//  Created by Sheetal Jha on 26/09/25.
//

import SwiftUI

struct CallLogRowView: View {
    let callLog: CallLogEntry
    let onVideoCallTap: () -> Void
    let onAudioCallTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(callLog.contactName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(callLog.callDirection == .missed ? Color(hex: "#CA292C") : Design.Color.primaryTextColor)
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Image(callLog.iconName)
                        .frame(width: 16, height: 16)
                    
                    Text(callLog.callState)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Design.Color.secondryTextColor)
                    
                    Spacer()
                }
            }
            
            Text(callLog.formattedTime)
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(Design.Color.primaryTextColor)
            
//            HStack(spacing: 16) {
//                Button(action: callLog.callType == .video ? onVideoCallTap : onAudioCallTap) {
//                    Image(callLog.callIconName)
//                        .resizable()
//                        .renderingMode(.template)
//                        .foregroundColor(Design.Color.primaryTextColor)
//                        .frame(width: 18, height: 18)
//                }
//            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = callLog.contactAvatarURL {
            AsyncImage(url: URL(string: avatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                defaultAvatarView
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            defaultAvatarView
        }
    }
    
    private var defaultAvatarView: some View {
        Circle()
            .fill(Design.Color.appGradient)
            .frame(width: 40, height: 40)
            .overlay(
                Text(callLog.contactName.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

//struct CallLogRowView_Previews: PreviewProvider {
//    static var previews: some View {
//        CallLogRowView(
//            callLog: CallLogEntry(
//                contactId: "1",
//                contactName: "John Doe",
//                contactPhoneNumber: "+1234567890",
//                callType: .voice,
//                callDirection: .incoming,
//                timestamp: Date().addingTimeInterval(-540),
//                duration: 120
//            ),
//            onVideoCallTap: {},
//            onAudioCallTap: {}
//        )
//        .background(Design.Color.chatBackground)
//    }
//}
