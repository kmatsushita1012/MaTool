import iOSShared
//
//  CheckpointEditContentView.swift
//  MaTool
//

import SwiftUI
import Shared

@available(iOS 17.0, *)
public struct CheckpointEditContentView: View {
    @Binding var item: Checkpoint
    let title: String
    let onDelete: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    public init(
        item: Binding<Checkpoint>,
        title: String,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self._item = item
        self.title = title
        self.onDelete = onDelete
        self.onCancel = onCancel
        self.onDone = onDone
    }

    public var body: some View {
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton(action: onCancel)
            ToolbarDoneButton(action: onDone)
        }
    }
}
