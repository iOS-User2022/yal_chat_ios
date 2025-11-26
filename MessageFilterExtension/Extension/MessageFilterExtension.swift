//
//  MessageFilterExtension.swift
//  MessageFilterExtension
//
//  Created by Vishal Bhadade on 25/04/25.
//

import IdentityLookup
import os

final class MessageFilterExtension: ILMessageFilterExtension {
    private let classifier = SpamClassifier(modelName: "tbsQ_31", vocabFile: "vocab")

    override init() {
        super.init()
        print("✅ Message Filter Extension Initialized")
    }
}

extension MessageFilterExtension: ILMessageFilterCapabilitiesQueryHandling, ILMessageFilterQueryHandling {

    func handle(_ capabilitiesRequest: ILMessageFilterCapabilitiesQueryRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterCapabilitiesQueryResponse) -> Void) {
        let response = ILMessageFilterCapabilitiesQueryResponse()
        completion(response)
    }

    func handle(_ queryRequest: ILMessageFilterQueryRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        os_log("📩 Message Received: %@", log: .default, type: .info, queryRequest.messageBody ?? "nil")

        let response = ILMessageFilterQueryResponse()
        guard let message = queryRequest.messageBody,
              let (category, probs) = classifier?.classify(message) else {
            response.action = .none
            completion(response)
            return
        }

        os_log("🔍 Prediction: %{public}@ | Probabilities: %{public}@",
               log: .default,
               type: .info,
               category.rawValue,
               probs.map { String(format: "%.2f", $0) }.joined(separator: ", "))

        switch category {
        case .spam:
            response.action = .junk
            SpamStorageManager.save(sender: queryRequest.sender ?? "Unknown", message: message)
        case .ham:
            response.action = .allow
        case .unknown:
            response.action = .none
        }

        completion(response)
    }

    private func offlineAction(for queryRequest: ILMessageFilterQueryRequest) -> (ILMessageFilterAction, ILMessageFilterSubAction) {
        // TODO: Replace with logic to perform offline check whether to filter first (if possible).
        return (.none, .none)
    }

    private func networkAction(for networkResponse: ILNetworkResponse) -> (ILMessageFilterAction, ILMessageFilterSubAction) {
        // TODO: Replace with logic to parse the HTTP response and data payload of `networkResponse` to return an action.
        return (.none, .none)
    }

}
