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
                }
            )
            .background {
                Color(UIColor.secondarySystemBackground)
                    .ignoresSafeArea(.container, edges: [.bottom, .top])
            }
            .navigationTitle("要注意区間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarDoneButton {
                    store.send(.doneTapped)
                }
                if isLiquidGlassEnabled, #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("戻る", systemImage: "arrow.uturn.backward") {
                            store.send(.undoTapped)
                        }
                        .disabled(!store.manager.canUndo)
                        Button("やり直す", systemImage: "arrow.uturn.forward") {
                            store.send(.redoTapped)
                        }
                        .disabled(!store.manager.canRedo)
                    }
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            store.send(.deleteTapped)
                        }
                        .tint(.red)
                    }
                } else {
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 8) {
                            Button("戻る", systemImage: "arrow.uturn.backward") {
                                store.send(.undoTapped)
                            }
                            .disabled(!store.manager.canUndo)
                            Button("やり直す", systemImage: "arrow.uturn.forward") {
                                store.send(.redoTapped)
                            }
                            .disabled(!store.manager.canRedo)
                            Spacer()
                            Button("削除", systemImage: "trash", role: .destructive) {
                                store.send(.deleteTapped)
                            }
                            .tint(.red)
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
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
