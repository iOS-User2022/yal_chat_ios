//
//  CopiedToastView.swift
//  YAL
//
//  Created by Vishal Bhadade on 20/06/25.
//

import SwiftUI

struct CopiedToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image("tick-white")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .padding(.vertical, 12)
                .padding(.leading, 16)
            
            Text(message)
                .font(Design.Font.medium(12))
                .foregroundColor(Design.Color.white)
                .padding(.vertical, 12)
                .padding(.trailing, 16)
        }
        .background(Design.Color.deepGreen) // Deep green
        .cornerRadius(8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
