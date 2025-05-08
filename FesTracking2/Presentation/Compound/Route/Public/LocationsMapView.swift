//
//  LocationsMapView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct LocationsMapView: View {
    @Bindable var store: StoreOf<LocationsMapFeature>
    
    var body: some View {
        RouteMap(
            locations: store.locations,
            pointTapped: {_ in },
            locationTapped: { store.send(.locationTapped($0)) }
        )
        .sheet(item: $store.scope(state: \.location, action: \.location)){ store in
            LocationView(store: store)
                .presentationDetents([.fraction(0.3)])
        }
    }
}
