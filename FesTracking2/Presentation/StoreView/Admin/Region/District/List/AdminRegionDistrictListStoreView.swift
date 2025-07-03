//
//  AdminRegionDistrictListView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionDistrictListView: View {
    @Bindable var store: StoreOf<AdminRegionDistrictList>
    
    var body: some View {
        NavigationView{
            Form{
                Section(header: Text("行動")) {
                    List(store.routes) { route in
                        NavigationItemView(
                            title: route.text(format: "m/d T"),
                            onTap: {
                                store.send(.exportTapped(route))
                            }
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        store.send(.dismissTapped)
                    }) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.district.name)
                        .bold()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(
                item: $store.scope(state: \.export, action: \.export)
            ) { store in
                AdminRouteExportView(store: store)
            }
            .loadingOverlay(store.isLoading)
        }
    }
}
