//
//  FloatingButton.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/07.
//

import SwiftUI

struct FloatingIconButton: View {
    let icon: String
    let action: @MainActor () -> Void
    @Environment(\.isLiquidGlassDisabled) private var isLiquidGlassDisabled

    init(
        icon: String,
        action: @escaping @MainActor () -> Void
    ) {
        self.icon = icon
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), !isLiquidGlassDisabled {
            glassButton
        } else {
            Button(action: {
                action()
            }) {
                Image(systemName: icon)
                    .font(.title3)
                    .padding(4)
            }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var glassButton: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .contentShape(.rect)
        }
        .buttonStyle(.glass)
    }
}

struct FloatingIconMenu<Item: Hashable>: View {
    let icon: String
    let items: [Item]
    let itemLabel: (Item) -> Text
    let onSelected: (Item) -> Void

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(action: {
                    onSelected(item)
                }) {
                    itemLabel(item)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .padding(4)
        }
    }
}
