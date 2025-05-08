//
//  NavigationItemView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/19.
//

import SwiftUI

struct NavigationItem: View {
    var title: String
    var iconName: String?
    var status: String? = nil
    var onTap: () -> Void

    var body: some View {
        HStack {
            if let iconName = iconName{
                Image(systemName: iconName)
                    .foregroundColor(.white) // アイコンは白
                    .padding(6) // アイコンの周りに余白
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue) // 背景は青
                    )
            }
            // アイテムタイトルを表示
            Text(title)
                .font(.body)
            Spacer()
            if let status = status {
                Text(status)
                    .font(.body)
                    .foregroundColor(.gray)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
