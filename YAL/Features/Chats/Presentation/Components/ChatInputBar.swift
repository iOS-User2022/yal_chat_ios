//
//  ChatInputBar.swift
//  YAL
//
//  Created by Vishal Bhadade on 17/04/25.
//

import SwiftUI

struct ChatInputBar: View {
    @Binding var message: String
    @Binding var senderName: String?
    @Binding var inReplyTo: ChatMessageModel?
    @Binding var pendingAttachments: [PendingAttachment]
    var typingUsers: [ContactModel]
    var onSend: () -> Void
    var onSendAudio: (URL) -> Void
    let onImageButtonTap: () -> Void
    var onCancelReply: (() -> Void)?
    @Binding var focusRequested: Bool
    @FocusState private var isTextFieldFocused: Bool

    @StateObject private var livePreviewFetcher = URLPreviewFetcher()
    @State private var showURLPreview = false
    @State private var currentPreviewURL: String?
    
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isRecording = false
    @State private var hasRecordingStarted = false
    
    var body: some View {
        VStack(spacing: UIConstants.Layout.tightSpacing) {
            // Typing indicator (shows above the input field)
            if !typingUsers.isEmpty {
                HStack(spacing: UIConstants.Layout.ProfileView.CameraButton.offset) {
                    Text(typingText)
                        .font(Design.ChatTextStyles.typingUser)
                        .italic()
                        .foregroundColor(.black)
                    TypingDotsView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UIConstants.Layout.ProfileView.AboutSection.textSpacing)
                .padding(.bottom, UIConstants.Layout.ProfileView.EditButton.shadowRadius)
                .transition(.opacity)
            }
            replyView()

            // Show live URL preview if URL detected
            if showURLPreview, let preview = livePreviewFetcher.previewData {
                HStack(alignment: .top, spacing: UIConstants.Layout.ProfileView.AboutSection.textSpacing) {
                    URLPreviewCard(previewData: preview) {
                        // Open URL in browser
                        if let url = URL(string: preview.url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        withAnimation {
                            showURLPreview = false
                            currentPreviewURL = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(Design.TextStyle.menuIconSize)
                    }
                    .padding(.top, UIConstants.Layout.ProfileView.AboutSection.textSpacing)
                }
                .padding(.horizontal, UIConstants.Layout.ProfileView.AboutSection.hPadding)
                .padding(.vertical, UIConstants.Layout.ProfileView.AboutSection.textSpacing)
                .background(Color(.systemGray6))
                .cornerRadius( UIConstants.Layout.ProfileView.AboutSection.hPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showURLPreview)
            }
            
            // INPUT BAR
            if isRecording {
                RecordingView(audioRecorder: audioRecorder, onSend: {
                    sendRecording()
                }, onCancel: {
                    audioRecorder.reset()
                    isRecording = false
                    hasRecordingStarted = false
                })
            }
            else {
                HStack(spacing:  UIConstants.Layout.ProfileView.AboutSection.hPadding) {
                    Button(action: onImageButtonTap) {
                        Image("add")
                            .frame(width:  UIConstants.Layout.ProfileView.EditButton.bottomPadding, height: UIConstants.Layout.ProfileView.EditButton.bottomPadding)
                            .background(
                                RoundedRectangle(cornerRadius:  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                                    .fill(Design.Color.white)
                            )
                    }

                    TextField("Meesage", text: $message)
                        .padding(.horizontal, UIConstants.Layout.ProfileView.ProfileField.hSpacing)
                        .padding(.vertical,  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                        .background(Color(Design.Color.darkgrayColor))
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Layout.ProfileView.AboutSection.textSpacing))
                        .shadow(color: Design.Color.black.opacity(UIConstants.Opacity.high),
                                radius: UIConstants.Layout.Radius.small, x: ChatLayout.inputBarBottomPad, y: ChatLayout.inputBarBottomPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: focusRequested) { newValue in  // ← ADD THIS
                                if newValue {
                                    isTextFieldFocused = true
                                    focusRequested = false
                                }
                            }
                    
                    if (!pendingAttachments.isEmpty) {
                        Button(action: onSend) {
                            Image("send")
                                .frame(width: UIConstants.Layout.ProfileView.EditButton.bottomPadding, height: UIConstants.Layout.ProfileView.EditButton.bottomPadding)
                                .background(
                                    RoundedRectangle(cornerRadius:  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                                        .fill(Design.Color.appGradient)
                                )
                        }
                    } else {
                        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                startRecording()
                            }) {
                                Image("fill_mic")
                                    .frame(width: UIConstants.Layout.ProfileView.EditButton.bottomPadding, height: UIConstants.Layout.ProfileView.EditButton.bottomPadding)
                                    .background(
                                        RoundedRectangle(cornerRadius:  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                                            .fill(Design.Color.appGradient)
                                    )
                            }
                        } else {
                            Button(action: onSend) {
                                Image("send")
                                    .frame(width: UIConstants.Layout.ProfileView.EditButton.bottomPadding, height: UIConstants.Layout.ProfileView.EditButton.bottomPadding)
                                    .background(
                                        RoundedRectangle(cornerRadius:  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                                            .fill(Design.Color.appGradient)
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, ChatLayout.senderLeadingPad)
        .padding(.top, inReplyTo == nil ? ChatLayout.senderLeadingPad :  UIConstants.Layout.ProfileView.AboutSection.hPadding)
        .padding(.bottom, ChatLayout.senderLeadingPad)
    }
    
    private func startRecording() {
        audioRecorder.reset()
        audioRecorder.startRecording()
        isRecording = true
        hasRecordingStarted = true
    }
    
    private func handleMessageChange(_ text: String) {
        let urls = URLDetector.extractURLs(from: text)
        
        if let firstURL = urls.first, URLDetector.isValidURL(firstURL) {
            // Only fetch if it's a new URL
            if currentPreviewURL != firstURL {
                currentPreviewURL = firstURL
                
                // Check cache first
                if let cachedPreview = URLPreviewCache.shared.getPreview(for: firstURL) {
                    livePreviewFetcher.previewData = cachedPreview
                    withAnimation {
                        showURLPreview = true
                    }
                } else {
                    // Debounce the fetch to avoid too many requests
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                        
                        // Check if URL still exists and is the same
                        if message.contains(firstURL), currentPreviewURL == firstURL {
                            await livePreviewFetcher.fetchPreview(for: firstURL)
                            
                            await MainActor.run {
                                if livePreviewFetcher.previewData != nil {
                                    withAnimation {
                                        showURLPreview = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // No valid URL found, hide preview
            withAnimation {
                showURLPreview = false
            }
            currentPreviewURL = nil
            livePreviewFetcher.previewData = nil
        }
    }
    
    private func sendRecording() {
        audioRecorder.mergeRecordings { url in
            if let url = url {
                onSendAudio(url)
            }
            audioRecorder.reset()
            isRecording = false
            hasRecordingStarted = false
        }
    }
    
    @ViewBuilder
    func replyView() -> some View {
        // REPLY PREVIEW
        if let reply = inReplyTo {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom) {
                    Text("\(senderName ?? "user")")
                        .font(Design.Font.medium(12))
                        .foregroundColor(Design.Color.primaryText)

                    Spacer()

                    Button(action: {
                        inReplyTo = nil
                        onCancelReply?()
                    }) {
                        Image("cross-black")
                            .resizable()
                            .frame(width:  UIConstants.Layout.ProfileView.AboutSection.hPadding, height:  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                    }
                }
                .padding(.horizontal,  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                .padding(.top, UIConstants.Layout.ProfileView.AboutSection.textSpacing)

                Text(reply.content)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText)
                    .padding(.horizontal,  UIConstants.Layout.ProfileView.AboutSection.hPadding)
                    .padding(.bottom, UIConstants.Layout.ProfileView.AboutSection.textSpacing)

            }
            .overlay(
                Rectangle()
                    .fill(Color.black)
                    .frame(width: UIConstants.Layout.ProfileView.EditButton.shadowRadius),
                alignment: .leading
            )
            .background(Color.gray.opacity(0.1))
            .cornerRadius(UIConstants.Layout.ProfileView.AboutSection.textSpacing)
            .padding(.horizontal, ChatLayout.inputBarBottomPad)
            .padding(.bottom,UIConstants.Layout.ProfileView.AboutSection.textSpacing)
            .frame(width: ChatLayout.replyViewWidth,height: ChatLayout.replyViewHeight)
        }
    }
    
    private var typingText: String {
        switch typingUsers.count {
        case 1:
            return "\(typingUsers[0].firstNameOrFallback)\(Constants.isTyping)"
        case 2:
            return "\(typingUsers[0].firstNameOrFallback) \(Constants.and) \(typingUsers[1].firstNameOrFallback) \(Constants.areTyping)"
        case let n where n > 2:
            let names = typingUsers.prefix(2).map { $0.firstNameOrFallback }.joined(separator: ", ")
            return "\(names) \(Constants.and) \(typingUsers.count - 2) \(Constants.othersTyping)"
        default:
            return ""
        }
    }
}
