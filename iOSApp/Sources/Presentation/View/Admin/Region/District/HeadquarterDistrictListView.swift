//
//  AdminFestivalDistrictListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct HeadquarterDistrictListView: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictListFeature>
    
    var body: some View {
        Form {
            Section(header: Text("参加町")) {
                ForEach(store.districts) { district in
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
