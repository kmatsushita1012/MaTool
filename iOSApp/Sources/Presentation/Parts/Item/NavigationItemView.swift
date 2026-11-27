//
//  NavigationItemView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/19.
//

import SwiftUI

struct NavigationItemView: View {
    let title: String
    var iconName: String? = nil
    var status: String? = nil
    var statusIconName: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                        )
                }
                Text(title)
                    .font(.body)
                Spacer()
                if let status {
                    HStack(spacing: 4) {
                        if let statusIconName {
                            Image(systemName: statusIconName)
                                .foregroundStyle(.tint)
                        }
                        Text(status)
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
