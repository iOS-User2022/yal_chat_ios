//
//  MessageInfoScreen.swift
//  YAL
//
//  Created by Hari krishna on 07/10/25.
//

import SwiftUI

extension Date {
    func formattedChatTimestamp() -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInYesterday(self) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM dd, h:mm a"
        }
        return formatter.string(from: self)
    }
}


struct SingleMessageInfoView: View {
    let message: ChatMessageModel
    let user: ContactModel
    let currentRoom: RoomModel
    @Binding var navPath: NavigationPath
    var topInsets: CGFloat = 0
    var screenWidth: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        headerSection
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                VStack {
                    SenderMessageView(
                        message: message,
                        senderName: "",
                        onDownloadNeeded: { _ in },
                        onTap: {},
                        onLongPress: {},
                        onScrollToMessage: {_ in },
                        selectedEventId: "",
                        searchText: ""

                    )
                }
                .padding(.vertical, 30.0)
            }

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Sent", time: formattedTime(message.timestamp), icon: "sent", isSystemImage: false)
                if message.messageStatus != .sent {
                    Divider()
                    InfoRow(title: message.messageStatus.imageName.capitalized, time: formattedTime(message.receipts.first?.timestamp ?? 0), icon: "info_read", isSystemImage: false)
                }
               
                //InfoRow(title: "Seen", time: "Today at 10:10", icon: "checkmark")
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            Spacer()
        }
        .padding()
        .background(AnyView(Design.Color.blueGradient.opacity(0.8)))

    }
    
    private func formattedTime(_ ts: Int64) -> String {
        if ts == 0 { return "--" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        return date.formattedChatTimestamp()
    }
    
    var headerSection: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                VStack {
                    Button(action: {
                        navPath.removeLast()
                    }) {
                        Image("back-long")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                    }
                    .padding(.leading, 10)
                    .frame(width: 40, height: 40)
                }
                Text("Message Info")
                    .font(Design.Font.semiBold(16.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, safeAreaTop())
        .background(Design.Color.white)
    }
    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.topSafeAreaInset
    }
}

struct InfoRow: View {
    let title: String
    let time: String
    let icon: String
    let isSystemImage: Bool
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                if isSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                } else {
                    Image(icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .aspectRatio(contentMode: .fit)
                }
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.black)
                Spacer()
            }
            HStack {
                Text(time)
                    .foregroundColor(.gray)
                    .font(.caption)
                Spacer()
            }
           
        }
    }
}
