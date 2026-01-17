//
//  RouteSlotView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/17.
//

import SwiftUI

struct RouteSlotView: View {
    let item: RouteSlot
    var onTap: (() -> Void)? = nil
    
    var status: String {
        item.route != nil ? "作成済" : "未作成"
    }
    
    init(_ item: RouteSlot, onTap: (() -> Void)? = nil) {
        self.item = item
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
