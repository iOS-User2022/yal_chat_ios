//
//  SMSListViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import Foundation
import Combine

@MainActor
class SMSListViewModel: ObservableObject {
    @Published var spamMessages: [SpamMessage] = []

    private var notificationCancellable: AnyCancellable?

    init() {
        loadMessages()
        observeSpamMessageUpdates()
    }

    func loadMessages() {
        let defaults = UserDefaults(suiteName: "group.yalchat.shared")
        if let raw = defaults?.array(forKey: "spamMessages") as? [[String: String]] {
            self.spamMessages = raw.compactMap { dict in
                guard let sender = dict["sender"], let message = dict["message"] else { return nil }
                return SpamMessage(sender: sender, message: message)
            }
        }
    }

    private func observeSpamMessageUpdates() {
        notificationCancellable = NotificationCenter.default.publisher(for: Notification.Name("spamMessagesUpdated"))
            .sink { [weak self] _ in
                self?.loadMessages()
                print("🔄 UI Updated with New Spam Messages")
            }
    }
}
