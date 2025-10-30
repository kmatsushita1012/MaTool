//
//  CardItem.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/03.
//

import SwiftUI

struct CardView: View {
    let title: String
    let foregroundColor: Color
    let backgroundColor: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title3)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

