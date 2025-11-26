//
//  AlertViewModel.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import Foundation

struct AlertActionModel: Identifiable {
    var id: UUID = UUID()
    var title: String
    var style: AlertActionStyle = .primary
    var action: () -> Void
}

enum AlertActionStyle {
    case primary
    case secondary
    case destructive
}

struct AlertViewModel: Identifiable {
    var id: UUID = UUID()
    var title: String
    var subTitle: String
    var imageName: String?
    var actions: [AlertActionModel]
}
