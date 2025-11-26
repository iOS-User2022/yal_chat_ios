//
//  GroupMessageInfoScreen.swift
//  YAL
//
//  Created by Hari krishna on 07/10/25.
//

import SwiftUI

struct GroupMessageInfoView: View {
    let message: ChatMessageModel
    let user: ContactModel
    let currentRoom: RoomModel
    @Binding var navPath: NavigationPath
    var topInsets: CGFloat = 0
    var screenWidth: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        headerSection
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            searchText: "")
                    }
                    .padding(.vertical, 30.0)

                }
//                let readBy = allRecepients.filter({ reciepient in
//                    reciepient.status == .read
//                })
                let allRecepients = message.receipts
                if !allRecepients.isEmpty {
                    VStack {
                        Section(header: HStack {
                            Text("Read by")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#01629C"))
                            Spacer()
                        }) {
                            Divider()
                                    .background(Color(hex: "#D0D8ED"))
                            memberList
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(AnyView(Design.Color.blueGradient.opacity(0.8)))
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
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }
    private var memberList: some View {
        VStack(spacing: 16) {
            ForEach(filteredMembers) { member in
                if let userId = member.userId, let currentUserId = user.userId, !member.phoneNumber.isEmpty, let fullName = member.fullName,
                   !fullName.isEmpty {
                    MemberRow(
                        member: member,
                        isCurrentUser: userId == currentUserId,
                        timeStampString: timeStampForMember(contact: member)
                    )
                }
            }
        }
    }
    
    private var filteredMembers: [ContactModel] {
        let baseList: [ContactModel]
        baseList = currentRoom.participants
        let allRecepients = message.receipts
        let readRecipientUserIds = allRecepients.filter { $0.status == .read }.map { $0.userId }
        let array = baseList.filter { contact in
            (readRecipientUserIds.contains(contact.userId) && contact.userId != user.userId)
        }
        return array.sorted { lhs, rhs in
            // Self user on top
            if lhs.userId == user.userId { return true }
            if rhs.userId == user.userId { return false }
            return lhs.fullName?.lowercased() ?? "" < rhs.fullName?.lowercased() ?? ""
        }
    }
    
    private func timeStampForMember(contact: ContactModel) -> String {
        let allRecepients = message.receipts
        if let memberStatus = allRecepients.filter({ receipent in
            receipent.userId == contact.userId
        }).first {
            return formattedTime(memberStatus.timestamp ?? 0)
        }
        return ""
    }
    
    private func formattedTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        return date.formattedChatTimestamp()
    }
    
}


struct MemberRow: View {
    let member: ContactModel
    let isCurrentUser: Bool
    let timeStampString: String
    @State private var downloadedImage: UIImage?
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            
            VStack(alignment: .leading, spacing: 2) {
                Text((isCurrentUser ? "You" : member.fullName) ?? "")
                    .font(Design.Font.semiBold(14))
                    .foregroundColor(Design.Color.primaryText)
                
                Text(timeStampString)
                    .font(Design.Font.regular(14))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
            }
               
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var avatarView: some View {
        Group {
            if let image = downloadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                initialsView
            }
        }.onAppear {
            guard downloadedImage == nil else { return } // prevent re-download
            print("member.avatarURL", member.avatarURL)
            if let httpUrl = member.avatarURL, !httpUrl.isEmpty {
                MediaCacheManager.shared.getMedia(
                    url: httpUrl,
                    type: .image,
                    progressHandler: { progress in
                        downloadProgress = progress
                    },
                    completion: { result in
                        switch result {
                        case .success(let imagePath):
                            var fileURL: URL
                            
                            if imagePath.hasPrefix("file://") {
                                if let url = URL(string: imagePath) {
                                    fileURL = url
                                } else {
                                    print("Invalid URL path: \(imagePath)")
                                    return
                                }
                            } else {
                                fileURL = URL(fileURLWithPath: imagePath)
                            }
                            // More efficient than loading Data first
                            if let uiImage = UIImage(contentsOfFile: fileURL.path) ?? {
                                // fallback if the path form fails for some reason
                                guard let data = try? Data(contentsOf: fileURL) else { return nil }
                                return UIImage(data: data)
                            }() {
                                // Optional: pre-decompress for smoother UI on iOS 15+
                                let finalImage = uiImage.preparingForDisplay() ?? uiImage
                                DispatchQueue.main.async {
                                    downloadedImage = finalImage
                                }
                            }

                        case .failure(let error):
                            print("❌ Failed to download media: \(error)")
                        }
                    }
                )
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.gray.opacity(0.2))
        .clipShape(Circle())
    }
    
    private var initialsView: some View {
        return Text(getInitials(from: member.fullName ?? ""))
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(member.randomeProfileColor.opacity(0.3))
            .clipShape(Circle())
    }
}
