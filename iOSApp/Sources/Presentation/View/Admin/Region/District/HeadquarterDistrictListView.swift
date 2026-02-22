//
//  HeadquarterDistrictListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl
import Shared

@available(iOS 17.0, *)
struct HeadquarterDistrictListView: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictListFeature>
    
    var body: some View {
        Form {
            Section {
                if store.isReordering {
                    ForEach(store.draftDistricts ?? store.districts.sorted()) { district in
                        Text(district.name)
                    }
                    .onMove { from, to in
                        store.send(.districtMoved(from: from, to: to))
                    }
                } else {
                    ForEach(store.filteredDistricts) { district in
                        NavigationItemView(
                            title: district.name,
                            onTap: {
                                store.send(.selected(district))
                            }
                        )
                    }
                }
            }
            #if DEBUG
            if !store.isReordering && store.searchText.isEmpty {
                Section {
                    Button(action: {
                        store.send(.batchExportTapped)
                    }) {
                        Text("経路図一括出力")
                    }
                }
            }
            #endif
        }
        .navigationTitle("参加町")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $store.searchText, prompt: "町名で検索", isEnabled: !store.isReordering)
        .sheet(item: $store.folder){ folder in
            ShareSheet(items: folder.files)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
        ) { store in
            HeadquarterDistrictDetailView(store: store)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.create, action: \.destination.create)
        ) { store in
            DistrictCreateView(store: store)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isReordering {
                    Button("完了") {
                        store.send(.reorderTapped)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("並替") {
                        store.send(.reorderTapped)
                    }
                    .disabled(store.isReorderDisabled)
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer()
            }
            if !store.isReordering {
                ToolbarItem(placement: .topBarTrailing){
                    Button("追加") {
                        store.send(.createTapped)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(store.isReordering ? .active : .inactive))
        .loadingOverlay(store.isLoading)
    }
}
