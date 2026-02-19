//
//  AdminPerformanceView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct PerformanceEditView:View {
    
    @SwiftUI.Bindable var store: StoreOf<PerformanceEditFeature>
    
    var body: some View {
        List {
            Section(header: Text("演目名")) {
                TextField("演目名を入力 (例:〇〇音頭)", text: $store.item.name)
            }
            Section(header: Text("演者")) {
                TextField("演者を入力 (例:小学生)", text: $store.item.performer)
            }
            Section(header: Text("紹介文")) {
                TextEditor(text: $store.item.description.nonOptional)
                    .frame(height:120)
            }
            if store.mode == .edit {
                Section {
                    Button(action: {
                        store.send(.deleteTapped)
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
                store.send(.cancelTapped)
            }
            ToolbarDoneButton {
                store.send(.doneTapped)
            }
        }
        .dismissible(backButton: false, edgeSwipe: false)
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
