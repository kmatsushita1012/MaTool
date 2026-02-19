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
    var footer: String?
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
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(errorMessage != nil ? Color.red : borderColor, lineWidth: 1.5)
                )
            }
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
