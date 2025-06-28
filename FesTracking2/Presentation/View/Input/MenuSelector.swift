//
//  MenuSelector.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/26.
//

import SwiftUI

struct MenuSelector<T: Hashable>: View {
    let title: String
    let items: [T]?
    @Binding var selection: T?
    let textForItem: (T?) -> String
    let isNullable: Bool
    var errorMessage: String?

    init(
        title: String,
        items: [T]? = nil,
        selection: Binding<T?>,
        textForItem: @escaping (T?) -> String,
        isNullable: Bool = true,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.items = items
        self._selection = selection
        self.textForItem = textForItem
        self.isNullable = isNullable
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Menu {
                if let items = items {
                    ForEach(items, id: \.self) { item in
                        Button(textForItem(item)) {
                            selection = item
                        }
                    }
                }
                if isNullable {
                    Button(textForItem(nil)) {
                        selection = nil
                    }
                }
            } label: {
                HStack {
                    Text(textForItem(selection))
                        .foregroundColor(selection == nil ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(errorMessage != nil ? Color.red : Color.blue, lineWidth: 1.5)
                )
            }

            // エラーメッセージ
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
