//
//  FullScreenImageView.swift
//  YAL
//
//  Created by Priyanka Singhnath on 03/09/25.
//

import SwiftUI
import SDWebImageSwiftUI
import AVKit

enum FullScreenImageSource {
    case uiImage(UIImage)
    case image(Image)
    case url(URL)
}

struct FullScreenImageView: View {
    let source: FullScreenImageSource
    let userName: String
    let timeText: String
    var mediaType: MediaType = .image
    var mediaUrl = ""
    var onForward: (() -> Void)?
    var onEdit: (() -> Void)?
    var onShare: (() -> Void)?
    
    @State private var player: AVPlayer?
    
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#0A171F").ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                
                if mediaType == .video {
                    if FileManager.default.fileExists(atPath: mediaUrl) {
                        let videoURL = URL(fileURLWithPath: mediaUrl)
                        VideoPlayer(player: player)
                            .frame(width: size.width, height: size.height)
                            .clipped()
                            .ignoresSafeArea()
                            .onAppear {
                                // Initialize and play
                                let avPlayer = AVPlayer(url: videoURL)
                                player = avPlayer
                                avPlayer.play()
                            }
                    } else {
                        Text("Video file not found")
                            .foregroundColor(.white)
                    }
                } else {
                    ZoomableImageView(source: source, size: size)
                }
            }
            
            // Top bar
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Back button
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                    }
                    
                    // User info
                    if !userName.isEmpty {
                        Text(userName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer().frame(height: 16)
                    
                  
                    Button(action: {
                        print("Edit button tapped")
                        onEdit?()
                    }) {
                        Image("edit-light")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                    }
                    Button(action: {
                        print("Share button tapped")
                        onShare?()
                    }) {
                        Image("share_icon")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                    }
                  
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .padding(.bottom, 8)
                .background(Color(hex: "#0A171F"))
            }
        }.onAppear(){
            print("usernmae $0: \(self.userName)")
        }
    }
}

// MARK: - ZoomableImageView
struct ZoomableImageView: UIViewRepresentable {
    let source: FullScreenImageSource
    let size: CGSize
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = UIColor(red: 0.039, green: 0.090, blue: 0.122, alpha: 1.0)
        
        let imageView: UIImageView
        switch source {
        case .uiImage(let uiImage):
            imageView = UIImageView(image: uiImage)
        case .image(let image):
            // Convert SwiftUI.Image to UIImage
            let uiImage = image.asUIImage(size: size) ?? UIImage()
            imageView = UIImageView(image: uiImage)
        case .url(let url):
            let placeholder = UIImage()
            imageView = UIImageView()
            SDWebImageDownloader.shared.downloadImage(with: url) { image, _, _, _ in
                DispatchQueue.main.async {
                    imageView.image = image ?? placeholder
                }
            }
        }
        
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.isUserInteractionEnabled = true
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            
            // Center the image when smaller than scrollView
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                       y: scrollView.contentSize.height * 0.5 + offsetY)
        }
    }
}

// MARK: - Helper to convert SwiftUI.Image to UIImage
extension Image {
    func asUIImage(size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: self.resizable().frame(width: size.width, height: size.height))
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view!.bounds, afterScreenUpdates: true)
        }
    }
}
