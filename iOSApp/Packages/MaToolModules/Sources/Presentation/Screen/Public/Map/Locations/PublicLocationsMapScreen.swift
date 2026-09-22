import iOSShared
import Application
import View
//
//  PublicLocationsMapScreen.swift
//  MaTool
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture
import MapKit

struct PublicLocationsMapScreen: View {
    @Perception.Bindable var store: StoreOf<PublicLocationsFeature>

    var body: some View {
        WithPerceptionTracking {
            @Binding(store.$mapRegion) var mapRegion
            PublicLocationsMapContentView(
                map: {
                    MapView(
                        style: .public,
                        floats: store.floats,
                        region: $mapRegion,
                        floatTapped: { store.send(.floatTapped($0)) }
                    )
                },
                controls: {
                    MapLocationsBottomControlsContent(
                        floats: store.floats,
                        onUserFocus: { store.send(.userFocusTapped) },
                        onFloatFocus: { store.send(.floatFocusSelected($0)) },
                        onReload: { store.send(.reloadTapped) }
                    )
                }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.detail) { location in
                LocationView(location)
                    .presentationDetents([.fraction(0.3)])
            }
        }
    }
}
