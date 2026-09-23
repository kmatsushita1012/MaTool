//
//  AdminLocationMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import UIKit
import MapKit
import SwiftUI

struct AdminLocationMap: UIViewRepresentable {
    var showsUserLocation: Bool = false
    var isTracking: Bool = false
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = showsUserLocation ? .follow : .none
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateUserLocation(
            on: mapView,
            isEnabled: showsUserLocation,
            isTracking: isTracking
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminLocationMap
        private var hasConfiguredUserLocation = false
        private var lastIsEnabled = false
        private var lastIsTracking = false
        private var didFocusMap = false

        init(_ parent: AdminLocationMap) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard parent.showsUserLocation, userLocation.location != nil, !didFocusMap else { return }
            focusUserLocationIfNeeded(on: mapView)
        }

        func updateUserLocation(on mapView: MKMapView, isEnabled: Bool, isTracking: Bool) {
            let shouldRestartUserLocation =
                !hasConfiguredUserLocation ||
                isEnabled != lastIsEnabled ||
                isTracking != lastIsTracking

            if !isEnabled {
                didFocusMap = false
                mapView.showsUserLocation = false
                mapView.setUserTrackingMode(.none, animated: false)
            } else if shouldRestartUserLocation {
                // MapKitの標準ユーザーロケーションを、権限・配信開始時に再開する。
                mapView.showsUserLocation = false
                mapView.setUserTrackingMode(.none, animated: false)
                mapView.showsUserLocation = true
                mapView.setUserTrackingMode(.follow, animated: false)
                didFocusMap = false
            } else {
                mapView.showsUserLocation = true
                mapView.setUserTrackingMode(.follow, animated: false)
            }

            hasConfiguredUserLocation = true
            lastIsEnabled = isEnabled
            lastIsTracking = isTracking
        }

        private func focusUserLocationIfNeeded(on mapView: MKMapView) {
            guard parent.showsUserLocation, let userLocation = mapView.userLocation.location else { return }
            setRegion(on: mapView, center: userLocation.coordinate)
            didFocusMap = true
        }

        private func setRegion(on mapView: MKMapView, center: CLLocationCoordinate2D) {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
            )
            mapView.setRegion(region, animated: false)
        }
    }
}
