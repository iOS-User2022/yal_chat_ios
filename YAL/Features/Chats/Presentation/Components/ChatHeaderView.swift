//
//  ChatHeaderView.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct ChatHeaderView: View {
    let title: String
    let subtitle: String
    let image: String?
    let color: Color?
    var backAction: (() -> Void)?
    @State private var downloadedImage: UIImage?
    private let processQ = DispatchQueue(label: "chat.vm.process", qos: .userInitiated)

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {
                backAction?()
            }) {
                Image("back-long")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            
            Spacer().frame(width: 12)
            
            ZStack {
                if let uiImage = downloadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(getInitials(from: title))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Color.primaryText.opacity(0.7))
                        .frame(width: 48, height: 48)  // Set the circle size
                        .background(color.opacity(0.3))
                        .clipShape(Circle())
                }
            }.onAppear {
                if let avatarUrl = image {
                    MediaCacheManager.shared.getMedia(
                        url: avatarUrl,
                        type: .image,
                        progressHandler: { _ in}
                    ) { result in
                        switch result {
                        case .success(let imagePath):
                            processQ.async {
                                let fileURL = imagePath.hasPrefix("file://") ? URL(string: imagePath)! : URL(fileURLWithPath: imagePath)
                                let ui = UIImage(contentsOfFile: fileURL.path) ?? (try? Data(contentsOf: fileURL)).flatMap(UIImage.init(data:))
                                let final = ui?.preparingForDisplay() ?? ui
                                DispatchQueue.main.async { self.downloadedImage = final }
                            }
                        case .failure(let e):
                            print("image load failed:", e)
                        }
                    }
                }
            }
            
            Spacer().frame(width: 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Design.Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top,0)
                Text(subtitle)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top,-8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer().frame(width: 12)

        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color.white)
    }
}
