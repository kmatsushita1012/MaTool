//
//  HazardSectionEditMap.swift
//  MaTool
//

import SwiftUI
import UIKit
import MapKit
import Shared

struct HazardSectionEditMap: MapViewRepresentable {
    var coordinates: [Coordinate]
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void
    var onSelect: (Coordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPress)

        if let region {
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        update(coordinates: coordinates, in: mapView)
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlay(PathPolyline(coordinates))
    }

    class Coordinator: MapCoordinator<HazardSectionEditMap> {
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }

        override func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            super.mapView(mapView, didSelect: view)
            guard let coordinate = view.annotation?.coordinate else { return }
            parent.onSelect(.fromCL(coordinate))
        }
    }
}
