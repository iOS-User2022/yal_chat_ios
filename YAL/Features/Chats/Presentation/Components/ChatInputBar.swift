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

    @StateObject private var livePreviewFetcher = URLPreviewFetcher()
    @State private var showURLPreview = false
    @State private var currentPreviewURL: String?
    
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isRecording = false
    @State private var hasRecordingStarted = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Typing indicator (shows above the input field)
            if !typingUsers.isEmpty {
                HStack(spacing: 6) {
                    Text(typingText)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .italic()
                        .foregroundColor(.secondary)
                    TypingDotsView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
                .transition(.opacity)
            }
            replyView()

            // Show live URL preview if URL detected
            if showURLPreview, let preview = livePreviewFetcher.previewData {
                HStack(alignment: .top, spacing: 8) {
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
                            .font(.system(size: 20))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
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
                HStack(spacing: 12) {
                    Button(action: onImageButtonTap) {
                        Image("add")
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    TextField("Message", text: $message)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 0)
                    
                    if (!pendingAttachments.isEmpty) {
                        Button(action: onSend) {
                            Image("send")
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                startRecording()
                            }) {
                                Image("fill_mic")
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Button(action: onSend) {
                                Image("send")
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, inReplyTo == nil ? 20 : 12)
        .padding(.bottom, 20)
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
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Text(reply.content)
                    .font(Design.Font.regular(12))
                    .foregroundColor(Design.Color.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

            }
            .overlay(
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2),
                alignment: .leading
            )
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 0)
            .padding(.bottom,8)
            .frame(width: 355,height: 66)
        }
    }
    
    private var typingText: String {
        switch typingUsers.count {
        case 1:
            return "\(typingUsers[0].firstNameOrFallback) is Typing"
        case 2:
            return "\(typingUsers[0].firstNameOrFallback) and \(typingUsers[1].firstNameOrFallback) are typing"
        case let n where n > 2:
            let names = typingUsers.prefix(2).map { $0.firstNameOrFallback }.joined(separator: ", ")
            return "\(names) and \(typingUsers.count - 2) others are typing"
        default:
            return ""
        }
    }
}
