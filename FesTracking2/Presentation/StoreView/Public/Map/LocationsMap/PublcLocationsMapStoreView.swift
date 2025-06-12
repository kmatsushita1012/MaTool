//
//  LocationsMapStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct LocationsMapStoreView: View {
    @Bindable var store: StoreOf<PublicLocationsMap>
    
    var body: some View {
        PublicMapView(
            locations: store.locations,
            locationTapped: { store.send(.locationTapped($0)) },
            region: $store.region
        )
        .sheet(item: $store.scope(state: \.location, action: \.location)){ store in
            LocationView(store: store)
                .presentationDetents([.fraction(0.3)])
        }
    }
}
