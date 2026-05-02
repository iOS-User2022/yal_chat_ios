//
//  CallMessageView.swift
//  YAL
//
//  Created by Sheetal Jha on 22/09/25.
//

import SwiftUI

struct CallMessageView: View, Equatable {
    let message: ChatMessageModel
    let isReceived: Bool
    let participantCount: Int
    var onCallBack: (() -> Void)?
    
    static func == (lhs: CallMessageView, rhs: CallMessageView) -> Bool {
        lhs.message.eventId == rhs.message.eventId &&
        lhs.isReceived == rhs.isReceived &&
        lhs.participantCount == rhs.participantCount
    }
    
    var body: some View {
        VStack(alignment: shouldShowOnLeft ? .leading : .trailing, spacing: 0) {
            HStack(spacing: 16) {
                callImage
                
                VStack(alignment: .leading) {
                    Text(callTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Design.Color.white)
                    
                    HStack {
                        Text(callSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Design.Color.white.opacity(0.8))

                        if shouldShowActionButton {
                            actionButton
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var callImage: some View {
        let imageName = getCallImageName()
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
    }
    
    private func getCallImageName() -> String {
        guard let callState = message.callState else {
            return shouldShowOnLeft ? "incomingCall" : "outgoingCall"
        }
        
        switch callState {
        case .incoming:
            return "incomingCall"
        case .outgoing:
            return "outgoingCall"
        case .decline, .declineWithMessage:
            return "missedCall"
        case .end:
            return shouldShowOnLeft ? "incomingCall" : "outgoingCall"
        case .ongoing:
            return shouldShowOnLeft ? "incomingCall" : "outgoingCall"
        case .idle:
            return ""
        }
    }
    
    private var shouldShowOnLeft: Bool {
        guard let callState = message.callState else { return isReceived }
        
        switch callState {
        case .incoming:
            return true
        case .outgoing:
            return false
        case .ongoing:
            return isReceived
        case .decline, .declineWithMessage:
            return isReceived
        case .end:
            return isReceived   
        case .idle:
            return isReceived
        }
    }
    
    private var callTitle: String {
        if message.msgType == "m.voiceCall" {
            return "Voice Call"
        } else {
            return "Video Call"
        }
    }
    
    private var callSubtitle: String {
        print("Callmanager ----------- cellview -> \(message.callStatus) -- lifetime -> \(message.lifetime)")
//        var str = message.lifetime ?? ""
//        str += message.callStatus ?? "Ended"
//        return str
        
        return message.content
        
//        guard let callState = message.callState else { return "Audio call" }
//        
//        switch callState {
//        case .incoming:
//            let participantText = participantCount > 2 ? " . \(participantCount) invited" : ""
//            return "Incoming\(participantText)"
//        case .outgoing:
//            let participantText = participantCount > 2 ? " . \(participantCount) invited" : ""
//            return "In call"
//        case .ongoing:
//            return "In call ."
//        case .decline:
//            let participantText = participantCount > 2 ? " . \(participantCount) invited" : ""
//            return "Declined\(participantText)"
//        case .declineWithMessage:
//            let participantText = participantCount > 2 ? " . \(participantCount) invited" : ""
//            return "Declined with message\(participantText)"
//        case .end:
//            let participantText = participantCount > 2 ? " . \(participantCount) invited" : ""
////                return "\(message.lifetime) . Ended"
//                return "2m . Ended"
//        case .idle:
//            return "Missed call"
//        }
    }
    
    // use for on-going call
    private var shouldShowActionButton: Bool {
        guard let callState = message.callState else { return false }
        switch callState {
        case .ongoing:
            return true
        default:
            return false
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        Button(action: {
            onCallBack?()
        }) {
            Text("Tap to join")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(shouldShowOnLeft ? Design.Color.black.opacity(0.8) : Design.Color.white.opacity(0.8))
        }
    }
    
    private var formattedTimestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval((message.timestamp) / 1000))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
