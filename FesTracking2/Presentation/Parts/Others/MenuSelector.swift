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
    var errorMessage: String?

    var hasError: Bool {
        errorMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ヘッダー
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            // Menu 選択部分
            Menu {
                Button("未設定") {
                    selection = nil
                }
                if let items = items {
                    ForEach(items, id: \.self) { item in
                        Button(textForItem(item)) {
                            selection = item
                        }
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
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasError ? Color.red : Color.blue, lineWidth: 1.5)
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
