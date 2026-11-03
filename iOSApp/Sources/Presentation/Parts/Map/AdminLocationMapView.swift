//
//  AdminLocationMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import MapKit
import SwiftUI

struct AdminLocationMap: View {
    var showsUserLocation: Bool = false
    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?

    var body: some View {
        Map(position: $position) {
            if showsUserLocation {
                UserAnnotation()
            }
        }
        .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
        .onAppear { updateTracking() }
        .onChange(of: showsUserLocation) { _, _ in updateTracking() }
    }

    private func updateTracking() {
        if showsUserLocation {
            position = .userLocation(fallback: .automatic)
        } else if let visibleRegion {
            position = .region(visibleRegion)
        }
    }
}
