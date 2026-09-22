import iOSShared
import Application
import View
//
//  HazardSectionScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/12/09.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct HazardSectionScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HazardSectionFeature>
    @Dependency(\.values.isLiquidGlassEnabled) var isLiquidGlassEnabled

    var body: some View {
        WithPerceptionTracking {
            HazardSectionContentView(
                item: $store.item,
                map: {
                    HazardSectionEditMap(
                        coordinates: store.item.coordinates,
                        region: $store.mapRegion,
                        onMapLongPress: { store.send(.mapLongPressed($0)) },
                        onSelect: { store.send(.pinSelected($0)) }
                    )
                },
                isLiquidGlassEnabled: isLiquidGlassEnabled,
                canUndo: store.manager.canUndo,
                canRedo: store.manager.canRedo,
                onDone: { store.send(.doneTapped) },
                onUndo: { store.send(.undoTapped) },
                onRedo: { store.send(.redoTapped) },
                onDelete: { store.send(.deleteTapped) }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .confirmationDialog(item: $store.selectedPin, title: { _ in Text("地点を編集") }) { item in
                Button("この地点の前に新しい地点を挿入") {
                    store.send(.insertBeforeTapped(item))
                }
                Button("この地点の後に新しい地点を挿入") {
                    store.send(.insertAfterTapped(item))
                }
                Button("削除", role: .destructive) {
                    store.send(.removeTapped(item))
                }
                Button("キャンセル") {
                    store.send(.menuClosed)
                }
            }
        }
    }
}
