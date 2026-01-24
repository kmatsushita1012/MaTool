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
struct AdminDistrictListView: View {
    @SwiftUI.Bindable var store: StoreOf<AdminDistrictList>
    
    var body: some View {
        List {
            Section(header: Text("ルート")) {
                ForEach(store.routes) { pair in
                    NavigationItemView(
                        title: pair.period.shortText,
                        onTap: {
                            store.send(.exportTapped(pair))
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
        .sheet(item: $store.folder){ folder in
            ShareSheet(folder.files)
        }
        .navigationDestination(
            item: $store.scope(state: \.export, action: \.export)
        ) { store in
            RouteEditView(store: store)
        }
        .loadingOverlay(store.isLoading)
    }
}
