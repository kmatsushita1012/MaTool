//
//  RouteMapView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/03.
//

import SwiftUI
import ComposableArchitecture

struct RouteMapView: View {
    @Bindable var store: StoreOf<RouteMapFeature>
    
    var body: some View {
        RouteMap(
            points: store.points,
            segments: store.segments,
            location: store.location,
            pointTapped: { store.send(.pointTapped($0))},
            locationTapped: { store.send(.locationTapped($0))}
        )
        .sheet(item: $store.scope(state: \.sheet?.point, action: \.sheet.point)) { store in
            PointView(store: store)
                .presentationDetents([.fraction(0.3)])
        }
        .sheet(item: $store.scope(state: \.sheet?.location, action: \.sheet.location)) { store in
            LocationView(store: store)
                .presentationDetents([.fraction(0.3)])
        }
    }
}
