import iOSShared
import Application
import View
//
//  PeriodEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/12/07.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PeriodEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PeriodEditFeature>

    var body: some View {
        WithPerceptionTracking {
            PeriodEditContentView(
                period: $store.period,
                isCreateMode: store.isCreateMode,
                onDateChanged: { store.send(.dateChanged($0)) },
                onDelete: { store.send(.deleteTapped) }
            )
            .navigationTitle(store.mode.title)
            .toolbar {
                ToolbarCancelButton {
                    store.send(.cancelTapped)
                }
                ToolbarSaveButton(isLoading: store.isLoading) {
                    store.send(.saveTapped)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
