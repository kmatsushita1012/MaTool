//
//  PublicLocationsMapStoreView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import SwiftUI
import ComposableArchitecture

struct PublicLocationsMapStoreView: View {
    @Bindable var store: StoreOf<PublicLocations>
    
    var body: some View {
        PublicLocationsMap(
            items: store.locations,
            onTap: { store.send(.locationTapped($0)) },
            region: $store.mapRegion
        )
        .sheet(item: $store.detail){ item in
            LocationView(item: item)
                .presentationDetents([.fraction(0.3)])
        }
    }
}
