//
//  PublicMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import SwiftUI

struct PublicMapView: View {
    @Perception.Bindable var store: StoreOf<PublicMapFeature>
    
    var body: some View {
        WithPerceptionTracking{
            VStack(spacing: 0){
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    PublicRouteMapView(store: routeStore)
                        .id(routeStore.district.id)
                } else if let store = store.scope(state: \.destination?.locations, action: \.destination.locations) {
                    PublicLocationsMapView(store: store)
                } else {
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    contentMenu
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                }
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    ToolbarItem(placement: .topBarLeading) {
                        periodMenu(routeStore: routeStore)
                    }
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .onAppear{
                store.send(.onAppear)
            }
        }
    }

    @ViewBuilder
    private var contentMenu: some View {
        Menu {
            ForEach(store.contents, id: \.self) { item in
                Button {
                    guard item != store.selectedContent else { return }
                    store.send(.contentSelected(item))
                } label: {
                    if item == store.selectedContent {
                        Label(item.text, systemImage: "checkmark")
                    } else {
                        Text(item.text)
                    }
                }
            }
        } label: {
            Text(store.selectedContent.text)
        }
        .overlay(alignment: .trailing) {
            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(store.isLoading)
    }

    @ViewBuilder
    private func periodMenu(routeStore: StoreOf<PublicRouteFeature>) -> some View {
        Menu {
            ForEach(routeStore.routes) { entry in
                Button {
                    routeStore.send(.selected(entry))
                } label: {
                    Text(entry.period.shortText)
                }
            }
        } label: {
            Text(routeStore.selected?.period.shortText ?? "日程を選択")
        }
        .overlay(alignment: .trailing) {
            if routeStore.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(store.isLoading || routeStore.isLoading || routeStore.routes.isEmpty)
    }

}
