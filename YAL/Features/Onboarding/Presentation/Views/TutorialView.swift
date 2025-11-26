//
//  TutorialView.swift
//  YAL
//
//  Created by Vishal Bhadade on 02/05/25.
//


import SwiftUI
import SDWebImageSwiftUI

struct TutorialView: View {
    @State private var currentPage = 0
    var onDismiss: ((Bool) -> Void)?
    
    private let steps = [
        (description: "Scroll to Unknown & Spam", imageName: "scroll-down"),
        (description: "Turn on Filter Unknown & Senders", imageName: "turn-on"),
        (description: "Enable YAL.ai", imageName: "logo-small")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack {
                    // Animated GIF at the top, constrained properly
                    AnimatedImage(name: "tutorial.gif") // Use the name of your GIF in the asset catalog
                        .playbackRate(0.8)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geometry.size.height * 0.5)
                        .clipped()
                        .padding(.horizontal, 33)
                        .padding(.top, 50)
                    
                    Spacer().frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading) {
                    Spacer()
                    
                    Text("Open message app settings")
                        .font(Design.Font.heavy(16))
                        .foregroundColor(Design.Color.black)
                        .lineLimit(nil)
                        .padding(.horizontal, 33)
                    
                    Spacer().frame(height: 24)
                    Spacer().frame(minHeight: 10, maxHeight: 24)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            HStack(spacing: 4) {  // Set 4px spacing between items
                                // Number
                                Text("\(index + 1).")
                                    .font(Design.Font.bold(14))
                                    .foregroundColor(Design.Color.black)
                                
                                // Image for each step
                                Image(steps[index].imageName)  // Load image corresponding to each step
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)  // Adjust the size of the image
                                
                                // Text description for each step
                                Text(steps[index].description)
                                    .font(Design.Font.bold(14))
                                    .foregroundColor(Design.Color.black)
                                    .lineLimit(nil)
                            }
                        }
                    }
                    .padding(.horizontal, 33)  // Padding for alignment

                    Spacer().frame(minHeight: 20, maxHeight: 57)

                    // Action button
                    Button(action: {
                        onDismiss?(true)
                    }) {
                        Text("Unknown & Spam")
                            .font(Design.Font.bold(16))
                            .frame(maxWidth: .infinity)
                            .frame(height: 63)
                            .background(Design.Color.appGradient)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal, 42)
                    
                    Spacer().frame(minHeight: 20, maxHeight: 44)
                }
                .frame(height: geometry.size.height * 0.4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure ZStack takes full screen
            .ignoresSafeArea(.all) // Ensure the content fills the screen, ignoring the safe area
        }
        .ignoresSafeArea(.all) // Ignore the safe area for the entire view
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        effectView.translatesAutoresizingMaskIntoConstraints = false
        return effectView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
