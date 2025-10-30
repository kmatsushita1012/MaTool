//
//  AdminRegionDistrictListView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

@available(iOS 17.0, *)
struct AdminRegionDistrictListView: View {
    @SwiftUI.Bindable var store: StoreOf<AdminRegionDistrictList>
    
    var body: some View {
        List {
            Section(header: Text("行動")) {
                ForEach(store.routes) { route in
                    NavigationItemView(
                        title: route.text(format: "m/d T"),
                        onTap: {
                            store.send(.exportTapped(route))
                        }
                    )
                }
            }
            Section {
                Button(action: {
                    store.send(.batchExportTapped)
                }) {
                    Text("経路図一括出力")
                }
            }
        }
        .navigationTitle(store.district.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $store.folder)
        { folder in
            ShareSheet(folder.files)
        }
        .navigationDestination(
            item: $store.scope(state: \.export, action: \.export)
        ) { store in
            AdminRouteEditStoreViewV2(store: store)
        }
        .loadingOverlay(store.isLoading)
    }
}
