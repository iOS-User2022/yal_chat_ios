//
//  GroupMessageInfoScreen.swift
//  YAL
//
//  Created by Hari krishna on 07/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

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
        UIApplication.shared.topSafeAreaInset
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
                            // Build a safe file URL from "file://..." or raw path
                            let fileURL: URL = {
                                if let u = URL(string: imagePath), u.scheme == "file" { return u }
                                return URL(fileURLWithPath: imagePath)
                            }()
                            
                            DispatchQueue.global(qos: .userInitiated).async {
                                autoreleasepool {
                                    do {
                                        // 1) Exists & not directory
                                        var isDir: ObjCBool = false
                                        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                                              !isDir.boolValue else {
                                            throw NSError(domain: "Media", code: 9001,
                                                          userInfo: [NSLocalizedDescriptionKey: "File missing or is a directory"])
                                        }
                                        
                                        // 2) Type-gate to images only
                                        if let ut = UTType(filenameExtension: fileURL.pathExtension),
                                           !ut.conforms(to: .image) {
                                            throw NSError(domain: "Media", code: 9002,
                                                          userInfo: [NSLocalizedDescriptionKey: "Not an image: \(ut.identifier)"])
                                        }
                                        
                                        // 3) Downsample (low memory)
                                        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                                        var ui: UIImage? = nil
                                        if let src = CGImageSourceCreateWithURL(fileURL as CFURL, srcOpts as CFDictionary) {
                                            let opts: [CFString: Any] = [
                                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                kCGImageSourceShouldCacheImmediately: true,
                                                kCGImageSourceCreateThumbnailWithTransform: true,
                                                kCGImageSourceThumbnailMaxPixelSize: 1536
                                            ]
                                            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
                                                ui = UIImage(cgImage: cg)
                                            }
                                        }
                                        
                                        // 4) Fallbacks
                                        if ui == nil { ui = UIImage(contentsOfFile: fileURL.path) }
                                        if ui == nil {
                                            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                                            ui = UIImage(data: data)
                                        }
                                        guard var img = ui else {
                                            throw NSError(domain: "Media", code: 9003,
                                                          userInfo: [NSLocalizedDescriptionKey: "Decode failed"])
                                        }
                                        
                                        if #available(iOS 15.0, *), let prepped = img.preparingForDisplay() { img = prepped }
                                        
                                        DispatchQueue.main.async { downloadedImage = img }
                                        
                                    } catch {
                                        print("❌ Media decode error — \(error.localizedDescription) | \(fileURL.path)")
                                    }
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
