import iOSShared
import Application
import View
//
//  PerformanceEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PerformanceEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PerformanceEditFeature>

    var body: some View {
        WithPerceptionTracking {
            PerformanceEditContentView(
                item: $store.item,
                isEditable: store.mode == .edit,
                onDelete: { store.send(.deleteTapped) },
                onCancel: { store.send(.cancelTapped) },
                onDone: { store.send(.doneTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
