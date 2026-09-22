import iOSShared
import Application
import View
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
            CheckpointEditContentView(
                item: $store.item,
                title: store.title,
                onDelete: { store.send(.deleteTapped) },
                onCancel: { store.send(.cancelTapped) },
                onDone: { store.send(.doneTapped) }
            )
        }
    }
}
