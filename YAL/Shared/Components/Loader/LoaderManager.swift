//
//  LoaderManager.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/04/25.
//


import SwiftUI
import Combine

final class LoaderManager: ObservableObject {
    static let shared = LoaderManager()
    
    @Published var isLoading: Bool = false

    private init() {}

    func show() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}
