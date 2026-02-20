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
    @State private var searchText: String = ""
    
    private var filteredDistricts: [District] {
        guard !searchText.isEmpty else { return store.districts }
        return store.districts.filter { $0.name.contains(searchText) }
    }
    
    var body: some View {
        Form {
            Section(header: Text("参加町")) {
                ForEach(filteredDistricts) { district in
                    NavigationItemView(
                        title: district.name,
                        onTap: {
                            store.send(.selected(district))
                        }
                    )
                }
            }
            #if DEBUG
                Section {
                    Button(action: {
                        store.send(.batchExportTapped)
                    }) {
                        Text("経路図一括出力")
                    }
                }
            #endif
        }
        .navigationTitle("参加町")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "町名で検索")
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
            ToolbarItem(placement: .primaryAction){
                Button(systemImage: "plus") {
                    store.send(.createTapped)
                }
            }
        }
        .loadingOverlay(store.isLoading)
    }
}
