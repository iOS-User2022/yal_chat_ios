//
//  ScreenshotBlockedCard.swift
//  YAL
//
//  Created by Priyanka Singhnath on 09/10/25.
//

import SwiftUI
import Combine
import AVKit

final class PrivacyProtectionManager: ObservableObject {
    @Published var showPrivacyOverlay = false
    
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenshot),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleScreenshot() {
        showPrivacyOverlay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            //self.showPrivacyOverlay = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct PrivacyOverlayView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            if isVisible {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    
                    Text("Screenshot blocked")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    ZStack {
                        Image("Subtract")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.black)
                    }
                    
                    Text("For adding privacy taking screenshot is disabled.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Button(action: {
                        isVisible = false
                    }) {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Design.Color.appGradient)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.horizontal, 16)
            }
        }
        .animation(.easeInOut, value: isVisible)
    }
}


// MARK: ScreenshotPreventView

struct ScreenshotPreventView<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }
    
    // view properties
    @State private var hostingController: UIHostingController<Content>?
    
    var body: some View {
        _ScreenshotPreventHelper(hostingController: $hostingController)
            .overlay{
                GeometryReader {
                    let size = $0.size
                    
                    Color.clear
                        .preference(key: SizeKey.self, value: size)
                        .onPreferenceChange(SizeKey.self, perform: { value in
                            if value != .zero {
                                
                                if hostingController == nil {
                                    hostingController = UIHostingController(rootView: content)
                                    hostingController?.view.backgroundColor = .clear
                                    hostingController?.view.tag = 1009
                                    hostingController?.view.frame = .init(origin: .zero
                                                                          , size: value)
                                } else {
                                    hostingController?.view.frame = .init(origin: .zero
                                                                          , size: value)
                                }
                            }
                        })
                }
            }
    }
}

fileprivate struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

fileprivate struct _ScreenshotPreventHelper<Content: View>: UIViewRepresentable {
    @Binding var hostingController: UIHostingController<Content>?
    
    func makeUIView(context: Context) -> UIView {
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        
        if let textLayoutView = secureField.subviews.first {
            return textLayoutView
        }
        
        return UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let hostingController, !uiView.subviews.contains(where: { $0.tag == 1009}) {
            uiView.addSubview(hostingController.view)
        }
    }
}


// MARK: ScreenshotPreventView

struct EmptyPreventView<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }
    
    // view properties
    @State private var hostingController: UIHostingController<Content>?
    
    var body: some View {
        _EmptyHelper(hostingController: $hostingController)
            .overlay{
                GeometryReader {
                    let size = $0.size
                    
                    Color.clear
                        .preference(key: SizeKey.self, value: size)
                        .onPreferenceChange(SizeKey.self, perform: { value in
                            if value != .zero {
                                
                                if hostingController == nil {
                                    hostingController = UIHostingController(rootView: content)
                                    hostingController?.view.backgroundColor = .clear
                                    hostingController?.view.tag = 1009
                                    hostingController?.view.frame = .init(origin: .zero
                                                                          , size: value)
                                } else {
                                    hostingController?.view.frame = .init(origin: .zero
                                                                          , size: value)
                                }
                            }
                        })
                }
            }
    }
}

fileprivate struct _EmptyHelper<Content: View>: UIViewRepresentable {
    @Binding var hostingController: UIHostingController<Content>?
    
    func makeUIView(context: Context) -> UIView {
        return UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let hostingController, !uiView.subviews.contains(where: { $0.tag == 1009}) {
            uiView.addSubview(hostingController.view)
        }
    }
}
