//
//  PerformanceEditView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct PerformanceEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PerformanceEditFeature>

    var body: some View {
        PerformanceEditContentView(
            name: $store.item.name,
            performer: $store.item.performer,
            description: $store.item.description.nonOptional,
            isEditing: store.mode == .edit,
            onDeleteTapped: { store.send(.deleteTapped) },
            onCancelTapped: { store.send(.cancelTapped) },
            onDoneTapped: { store.send(.doneTapped) }
        )
        .dismissible(backButton: false, edgeSwipe: false)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

@available(iOS 17.0, *)
typealias PerformanceEditView = PerformanceEditScreen

@available(iOS 17.0, *)
struct PerformanceEditContentView: View {
    @Binding var name: String
    @Binding var performer: String
    @Binding var description: String
    let isEditing: Bool
    let onDeleteTapped: () -> Void
    let onCancelTapped: () -> Void
    let onDoneTapped: () -> Void

    var body: some View {
        List {
            Section(header: Text("演目名")) {
                TextField("演目名を入力 (例:〇〇音頭)", text: $name)
            }
            Section(header: Text("演者")) {
                TextField("演者を入力 (例:小学生)", text: $performer)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $description)
                    .frame(height: 120)
            }
            if isEditing {
                Section {
                    Button(action: {
                        onDeleteTapped()
                    }) {
                        Text("削除")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("余興")
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
    PerformanceEditContentView(
        name: .constant(""),
        performer: .constant(""),
        description: .constant(""),
        isEditing: false,
        onDeleteTapped: {},
        onCancelTapped: {},
        onDoneTapped: {}
    )
}
