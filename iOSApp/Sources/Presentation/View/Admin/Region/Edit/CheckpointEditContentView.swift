//
//  CheckpointEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
struct CheckpointEditContentView: View {
    @Binding var item: Checkpoint
    let onDelete: () -> Void

    var body: some View {
        List {
            Section(header: Text("名称")) {
                TextField("名称を入力", text: $item.name)
            }
            Section(header: Text("詳細")) {
                TextEditor(text: $item.description.nonOptional)
                    .frame(height: 60)
            }
            Section {
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                    .foregroundStyle(.red)
            }
        }
    }
}
