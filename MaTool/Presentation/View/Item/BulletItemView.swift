//
//  CircleItem.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/07.
//

import SwiftUI

struct BulletItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.circle")
                .font(.title3)
                .foregroundColor(.gray)
                .padding(.leading, 8)
            Text(text)
                .font(.title3)
        }
    }
}
