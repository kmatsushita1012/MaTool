//
//  PublicLocationsMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture
import MapKit

struct PublicLocationsMapView: View {
    @Perception.Bindable var store: StoreOf<PublicLocationsFeature>

    var body: some View {
        WithPerceptionTracking{
            @Binding(store.$mapRegion) var mapRegion
            mapView(region: $mapRegion)
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.detail){ location in
                LocationView(location)
                    .presentationDetents([.fraction(0.3)])
            }
        }
    }

    @ViewBuilder
    private func mapView(region: Binding<MKCoordinateRegion>) -> some View {
        let map = MapView(
            style: .public,
            floats: store.floats,
            region: region,
            floatTapped: { store.send(.floatTapped($0)) }
        )
        .ignoresSafeArea()

        if #available(iOS 26.0, *) {
            map
                .scrollEdgeEffectStyle(.soft, for: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MapLocationsBottomControlsView(store: store)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, MapGlassControlVariant.toolbar.edgeSpacing)
                    .padding(.bottom, 8)
                }
        } else {
            map.safeAreaInset(edge: .bottom, spacing: 0) {
                MapLocationsBottomControlsView(store: store)
                    .padding(.bottom, 72)
            }
        }
    }

}
