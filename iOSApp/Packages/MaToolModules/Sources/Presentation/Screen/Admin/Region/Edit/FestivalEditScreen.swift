import iOSShared
import Application
import View
//
//  FestivalEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/17.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct FestivalEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<FestivalEditFeature>

    var body: some View {
        WithPerceptionTracking {
            FestivalEditContentView(
                festival: $store.festival,
                checkpoints: store.checkpoints,
                hazardSections: store.hazardSections,
                baseStatusText: store.baseStatusText,
                onBaseTapped: { store.send(.baseTapped) },
                onCheckpointEdit: { store.send(.onCheckpointEdit($0)) },
                onCheckpointAdd: { store.send(.onCheckpointAdd) },
                onHazardTapped: { store.send(.hazardTapped($0)) },
                onHazardAdd: { store.send(.hazardCreateTapped) },
                isLoading: store.isLoading,
                onCancel: { store.send(.cancelTapped) },
                onSave: { store.send(.saveTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .fullScreenCover(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .base(let store):
                    DistrictBaseEditScreen(store: store)
                case .checkpoint(let store):
                    CheckpointEditScreen(store: store)
                case .hazard(let store):
                    HazardSectionScreen(store: store)
                }
            }
        }
    }
}


private extension FestivalEditFeature.State {
    var baseStatusText: String {
        base == nil ? "未設定" : "設定済み"
    }
}
