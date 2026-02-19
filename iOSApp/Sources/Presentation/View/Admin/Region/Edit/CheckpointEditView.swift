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
struct CheckpointEditView: View {
    
    @SwiftUI.Bindable var store: StoreOf<CheckpointEditFeature>
    
    var body: some View {
        List {
            Section(header: Text("名称")) {
                TextField("名称を入力", text: $store.item.name)
            }
            Section(header: Text("詳細")) {
                TextEditor(text: $store.item.description.nonOptional)
                    .frame(height:60)
            }
        }
        .navigationTitle(store.title)
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
    }
}
