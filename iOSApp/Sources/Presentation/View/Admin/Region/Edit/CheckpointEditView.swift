//
//  CheckpointEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/25.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct CheckpointEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<CheckpointEditFeature>

    var body: some View {
        CheckpointEditContentView(
            name: $store.item.name,
            description: $store.item.description.nonOptional,
            title: store.title,
            onDeleteTapped: { store.send(.deleteTapped) },
            onCancelTapped: { store.send(.cancelTapped) },
            onDoneTapped: { store.send(.doneTapped) }
        )
        .dismissible(backButton: false, edgeSwipe: false)
    }
}

@available(iOS 17.0, *)
typealias CheckpointEditView = CheckpointEditScreen

@available(iOS 17.0, *)
struct CheckpointEditContentView: View {
    @Binding var name: String
    @Binding var description: String
    let title: String
    let onDeleteTapped: () -> Void
    let onCancelTapped: () -> Void
    let onDoneTapped: () -> Void

    var body: some View {
        List {
            Section(header: Text("名称")) {
                TextField("名称を入力", text: $name)
            }
            Section(header: Text("詳細")) {
                TextEditor(text: $description)
                    .frame(height: 60)
            }
            Section {
                Button("削除", systemImage: "trash", role: .destructive) {
                    onDeleteTapped()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarCancelButton {
                onCancelTapped()
            }
            ToolbarDoneButton {
                onDoneTapped()
            }
        }
    }
}

#Preview {
    CheckpointEditContentView(
        name: .constant(""),
        description: .constant(""),
        title: "",
        onDeleteTapped: {},
        onCancelTapped: {},
        onDoneTapped: {}
    )
}
