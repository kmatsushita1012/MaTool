//
//  AdminRegionDistrictListView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture
import NavigationSwipeControl

struct AdminRegionDistrictListView: View {
    @Bindable var store: StoreOf<AdminRegionDistrictList>
    
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
        }
        .navigationTitle(store.district.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            item: $store.scope(state: \.export, action: \.export)
        ) { store in
            AdminRouteExportView(store: store)
        }
        .loadingOverlay(store.isLoading)
    }
}
