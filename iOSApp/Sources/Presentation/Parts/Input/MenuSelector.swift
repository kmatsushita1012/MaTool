//
//  MenuSelector.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/26.
//

import SwiftUI

struct MenuSelector<T: Hashable>: View {
    var title: String? = nil
    let items: [T]?
    @Binding var selection: T?
    let label: (T?) -> String
    var isNullable: Bool = true
    var errorMessage: String?
    var footer: String? = nil
    var borderColor: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Menu {
                if let items = items?.reversed() {
                    ForEach(items, id: \.self) { item in
                        Button(label(item)) {
                            selection = item
                        }
                    }
                }
                if isNullable {
                    Button(label(nil)) {
                        selection = nil
                    }
                }
            } label: {
                HStack {
                    Text(label(selection))
                        .foregroundColor(selection == nil ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(
                SecondaryButtonStyle(
                    foregroundColor: .primary,
                    borderColor: errorMessage != nil ? .red : borderColor
                )
            )
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if let footer = footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
