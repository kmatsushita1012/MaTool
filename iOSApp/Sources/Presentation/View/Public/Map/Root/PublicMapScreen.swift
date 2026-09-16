//
//  PublicMapScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import Shared
import SwiftUI

struct PublicMapScreen: View {
    @Perception.Bindable var store: StoreOf<PublicMapFeature>

    var body: some View {
        WithPerceptionTracking {
            PublicMapContentView {
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    PublicRouteMapScreen(store: routeStore)
                        .id(routeStore.district.id)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            MapTopControlsContentView(
                                contents: store.contents,
                                selectedContent: store.selectedContent,
                                isLoading: store.isLoading,
                                onContentSelected: { store.send(.contentSelected($0)) },
                                routes: routeStore.routes,
                                selectedPeriodTitle: routeStore.selected?.period.mapMenuText ?? "日程を選択",
                                isRouteLoading: routeStore.isLoading,
                                isPeriodDisabled: store.isLoading,
                                onPeriodSelected: { routeStore.send(.selected($0)) }
                            )
                        }
                } else if let locationsStore = store.scope(state: \.destination?.locations, action: \.destination.locations) {
                    PublicLocationsMapScreen(store: locationsStore)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            MapTopControlsContentView(
                                contents: store.contents,
                                selectedContent: store.selectedContent,
                                isLoading: store.isLoading,
                                onContentSelected: { store.send(.contentSelected($0)) },
                                routes: nil,
                                selectedPeriodTitle: "日程を選択",
                                isRouteLoading: false,
                                isPeriodDisabled: true,
                                onPeriodSelected: { _ in }
                            )
                        }
                } else {
                    Spacer()
                }
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        MapFestivalToolbarTitleContentView(title: store.contents.first?.name ?? "")
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        MapFestivalToolbarTitleContentView(title: store.contents.first?.name ?? "")
                    }
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}
