//
//  FloatingButton.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/07.
//

import SwiftUI

struct FloatingIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: icon)
                .font(.title3)
                .padding(4)
        }
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
