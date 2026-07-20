//
//  RouteSlotView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/17.
//

import SwiftUI

struct RouteSlotView: View {
    let item: RouteSlot
    let statusText: String
    var onTap: (() -> Void)? = nil
    
    var status: String {
        statusText
    }
    
    init(_ item: RouteSlot, statusText: String? = nil, onTap: (() -> Void)? = nil) {
        self.item = item
        self.statusText = statusText ?? (item.route != nil ? "作成済" : "未作成")
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack {
                Text(item.text)
                    .foregroundStyle(.primary)
                Spacer()
                Text(status)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
