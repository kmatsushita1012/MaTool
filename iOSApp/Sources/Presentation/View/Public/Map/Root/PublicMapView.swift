//
//  PublicMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/19.
//

import ComposableArchitecture
import Shared
import SwiftUI

struct PublicMapView: View {
    @Perception.Bindable var store: StoreOf<PublicMapFeature>
    
    var body: some View {
        WithPerceptionTracking{
            ZStack {
                if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                    PublicRouteMapView(store: routeStore)
                        .id(routeStore.district.id)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            MapTopControlsScreen(store: store)
                        }
                } else if let locationsStore = store.scope(state: \.destination?.locations, action: \.destination.locations) {
                    PublicLocationsMapView(store: locationsStore)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            MapTopControlsScreen(store: store)
                        }
                } else {
                    Spacer()
                }
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        MapFestivalToolbarTitleView(store: store)
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        MapFestivalToolbarTitleView(store: store)
                    }
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
            .onAppear{
                store.send(.onAppear)
            }
        }
    }
}

private struct MapFestivalToolbarTitleView: View {
    let store: StoreOf<PublicMapFeature>

    var body: some View {
        WithPerceptionTracking {
            MapFestivalToolbarTitleContentView(title: store.contents.first?.name ?? "")
        }
    }
}

private struct MapFestivalToolbarTitleContentView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MapTopControlsScreen: View {
    let store: StoreOf<PublicMapFeature>

    var body: some View {
        WithPerceptionTracking {
            let contentMenu = MapContentMenuContentView(
                contents: store.contents,
                selectedContent: store.selectedContent,
                isLoading: store.isLoading,
                onSelected: { store.send(.contentSelected($0)) }
            )

            if let routeStore = store.scope(state: \.destination?.route, action: \.destination.route) {
                MapTopControlsContentView(
                    contentMenu: contentMenu,
                    periodMenu: MapPeriodMenuContentView(
                        routes: routeStore.routes,
                        selectedTitle: routeStore.selected?.period.shortText ?? "日程を選択",
                        isLoading: routeStore.isLoading,
                        isDisabled: store.isLoading,
                        onSelected: { routeStore.send(.selected($0)) }
                    )
                )
            } else {
                MapTopControlsContentView(
                    contentMenu: contentMenu,
                    periodMenu: nil
                )
            }
        }
    }
}

private struct MapTopControlsContentView: View {
    let contentMenu: MapContentMenuContentView
    let periodMenu: MapPeriodMenuContentView?

    var body: some View {
        HStack(spacing: 16) {
            contentMenu
            if let periodMenu {
                periodMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

private struct MapContentMenuContentView: View {
    let contents: [PublicMapFeature.Content]
    let selectedContent: PublicMapFeature.Content
    let isLoading: Bool
    let onSelected: (PublicMapFeature.Content) -> Void

    var body: some View {
        Menu {
            ForEach(contents, id: \.self) { item in
                Button {
                    guard item != selectedContent else { return }
                    onSelected(item)
                } label: {
                    if item == selectedContent {
                        Label(item.text, systemImage: "checkmark")
                    } else {
                        Text(item.text)
                    }
                }
            }
        } label: {
            Text(selectedContent.text)
        }
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isLoading)
        .modifier(MapTopMenuButtonStyleModifier())
    }
}

private struct MapPeriodMenuContentView: View {
    let routes: [RouteEntry]
    let selectedTitle: String
    let isLoading: Bool
    let isDisabled: Bool
    let onSelected: (RouteEntry) -> Void

    var body: some View {
        Menu {
            ForEach(routes) { entry in
                Button {
                    onSelected(entry)
                } label: {
                    Text(entry.period.shortText)
                }
            }
        } label: {
            Text(selectedTitle)
        }
        .overlay(alignment: .trailing) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .disabled(isDisabled || isLoading || routes.isEmpty)
        .modifier(MapTopMenuButtonStyleModifier())
    }
}

private struct MapTopMenuButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonSizing(.fitted)
                .controlSize(.large)
        } else {
            content
                .menuStyle(.button)
                .buttonStyle(.plain)
                .controlSize(.large)
        }
    }
}
