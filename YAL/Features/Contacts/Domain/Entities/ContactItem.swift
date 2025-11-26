//
//  ContactItem.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//

import Foundation
import SwiftUI

struct ContactItem: Identifiable {
    let id = UUID()
    let fullName: String
    let phoneNumber: String
    let image: UIImage?
}
