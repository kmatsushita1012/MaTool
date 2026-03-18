//
//  PassageItemView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/02/18.
//

import SwiftUI
import SQLiteData
import Shared

struct PassageItemView: View {
    let passage: RoutePassage
    @FetchOne var district: District?

    let canMoveUp: Bool
    let canMoveDown: Bool
    let onInsertAbove: () -> Void
    let onInsertBelow: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    init(
        passage: RoutePassage,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onInsertAbove: @escaping () -> Void,
        onInsertBelow: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.passage = passage
        self._district = FetchOne(District.find(passage.districtId ?? "__none__"))
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onInsertAbove = onInsertAbove
        self.onInsertBelow = onInsertBelow
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onDelete = onDelete
    }
    
    private var title: String {
        if let district {
            return district.name
        }
        if let memo = passage.memo?.trimmingCharacters(in: .whitespacesAndNewlines), !memo.isEmpty {
            return memo
        }
        return "(未設定)"
    }

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)

            Text(title)

            Spacer()

            Menu {
                Button("上に追加", systemImage: "plus.circle") {
                    onInsertAbove()
                }

                Button("下に追加", systemImage: "plus.circle") {
                    onInsertBelow()
                }

                Divider()

                Button("上へ移動", systemImage: "arrow.up") {
                    onMoveUp()
                }
                .disabled(!canMoveUp)

                Button("下へ移動", systemImage: "arrow.down") {
                    onMoveDown()
                }
                .disabled(!canMoveDown)

                Divider()

                Button("削除", systemImage: "trash", role: .destructive) {
                    onDelete()
                }

            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
