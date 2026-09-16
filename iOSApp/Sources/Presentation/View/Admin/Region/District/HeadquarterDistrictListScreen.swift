//
//  HeadquarterDistrictListScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct HeadquarterDistrictListScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictListFeature>

    var body: some View {
        WithPerceptionTracking {
            HeadquarterDistrictListContentView(
                isReordering: store.isReordering,
                searchText: $store.searchText,
                draftDistricts: store.draftDistricts,
                districts: store.districts,
                filteredDistricts: store.filteredDistricts,
                isExportLoading: store.isExportLoading,
                onDistrictSelected: { store.send(.selected($0)) },
                onDistrictMoved: { store.send(.districtMoved(from: $0, to: $1)) },
                onBatchExport: { store.send(.batchExportTapped) }
            )
            .navigationTitle("参加町")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.searchText, prompt: "町名で検索", isEnabled: !store.isReordering)
            .sheet(item: $store.folder) { folder in
                ShareSheet(items: folder.files)
            }
            .navigationDestination(item: $store.scope(state: \.destination, action: \.destination)) { destination in
                switch destination.case {
                case .detail(let store):
                    HeadquarterDistrictDetailScreen(store: store)
                }
            }
            .fullScreenCover(item: $store.scope(state: \.editDestination, action: \.editDestination)) { destination in
                switch destination.case {
                case .create(let store):
                    DistrictCreateScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isReordering {
                        Button("完了", action: { store.send(.reorderTapped) })
                            .buttonStyle(.borderedProminent)
                            .overlay {
                                if store.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .disabled(store.isLoading)
                    } else {
                        Button("並替", action: { store.send(.reorderTapped) })
                            .disabled(store.isReorderDisabled || store.isLoading)
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer()
                }
                if !store.isReordering {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("追加", action: { store.send(.createTapped) })
                    }
                }
            }
            .environment(\.editMode, .constant(store.isReordering ? .active : .inactive))
        }
    }
}
