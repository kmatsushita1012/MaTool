//
//  HeadquarterDistrictDetailScreen.swift
//  MaTool
//  Created by 松下和也 on 2026/01/24.
//

import SwiftUI
import ComposableArchitecture

@available(iOS 17.0, *)
struct HeadquarterDistrictDetailScreen: View {
    @SwiftUI.Bindable var store: StoreOf<HeadquarterDistrictDetailFeature>

    var body: some View {
        WithPerceptionTracking {
            HeadquarterDistrictDetailContentView(
                district: $store.district,
                displayedOrder: $store.displayedOrder,
                routes: store.routes,
                routeDrafts: store.routeDrafts,
                isEditable: store.isEditable,
                isSubmissionExportLoading: store.isSubmissionExportLoading,
                isTableExportLoading: store.isTableExportLoading,
                onRouteSelected: { store.send(.routeSelected($0)) },
                onResetDrafts: { store.send(.resetDraftsTapped) },
                onSubmissionExport: { store.send(.batchExportTapped) },
                onTableExport: { store.send(.tableExportTapped) },
                onReissue: { store.send(.reissueTapped) }
            )
            .navigationTitle(store.district.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.isEditable {
                    ToolbarSaveButton(
                        isLoading: store.isLoading
                            && !store.isSubmissionExportLoading
                            && !store.isTableExportLoading
                    ) {
                        store.send(.editTapped)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編集") {
                            store.send(.editTapped)
                        }
                    }
                }
            }
            .sheet(item: $store.url) { url in
                ShareSheet(item: url)
            }
            .fullScreenCover(
                item: $store.scope(state: \.editDestination, action: \.editDestination)
            ) { destination in
                switch destination.case {
                case .route(let store):
                    RouteEditScreen(store: store)
                }
            }
            .navigationDestination(
                item: $store.scope(state: \.destination, action: \.destination)
            ) { destination in
                switch destination.case {
                case .reissue(let store):
                    DistrictReissueScreen(store: store)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}
