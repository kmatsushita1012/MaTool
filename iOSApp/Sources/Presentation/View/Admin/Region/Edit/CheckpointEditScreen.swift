//
//  CheckpointEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/06/25.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct CheckpointEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<CheckpointEditFeature>

    var body: some View {
        WithPerceptionTracking {
            CheckpointEditContentView(item: $store.item) {
                store.send(.deleteTapped)
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
        }
    }
}
