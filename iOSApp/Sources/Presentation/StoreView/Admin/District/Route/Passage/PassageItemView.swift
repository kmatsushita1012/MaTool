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
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    init(
        passage: RoutePassage,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.passage = passage
        self._district = FetchOne(District.find(passage.districtId))
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onDelete = onDelete
    }

    var body: some View {
        if let district {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)

                Text(district.name)

                Spacer()

                Menu {
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
        } else {
            Text("データがありません")
        }
    }
}
