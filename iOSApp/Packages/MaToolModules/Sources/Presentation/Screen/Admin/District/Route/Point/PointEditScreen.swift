import iOSShared
import Application
import View
//
//  PointEditScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/04/08.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct PointEditScreen: View {
    @SwiftUI.Bindable var store: StoreOf<PointEditFeature>

    var body: some View {
        WithPerceptionTracking {
            PointEditContentView(
                point: $store.point,
                pointType: $store.pointType,
                validTypes: store.validTypes,
                checkpoints: store.checkpoints,
                performances: store.performances,
                selectedCheckpointName: store.selectedCheckpoint?.name,
                selectedPerformanceName: store.selectedPerformance?.name,
                onMove: { store.send(.moveTapped) },
                onInsertBefore: { store.send(.insertBeforeTapped) },
                onInsertAfter: { store.send(.insertAfterTapped) },
                onDelete: { store.send(.deleteTapped) },
                onCancel: { store.send(.cancelTapped) },
                onDone: { store.send(.doneTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
