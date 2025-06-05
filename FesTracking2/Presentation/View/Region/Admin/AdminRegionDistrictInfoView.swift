//
//  AdminRegionDistrictInfoView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/12.
//

import SwiftUI
import ComposableArchitecture

struct AdminRegionDistrictInfoView: View {
    @Bindable var store: StoreOf<AdminRegionDistrictInfoFeature>
    
    var body: some View {
        NavigationStack{
            Form{
                Section(header: Text("経路")) {
                    List(store.routes) { route in
                        NavigationItem(
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
        }
    }
}
