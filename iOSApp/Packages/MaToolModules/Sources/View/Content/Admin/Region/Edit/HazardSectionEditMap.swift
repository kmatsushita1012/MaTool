import iOSShared
//
//  HazardSectionEditMap.swift
//  MaTool
//

import SwiftUI
import UIKit
import MapKit
import Shared

public struct HazardSectionEditMap: MapViewRepresentable {
    var coordinates: [Coordinate]
    @Binding public var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void
    var onSelect: (Coordinate) -> Void

    public init(
        coordinates: [Coordinate],
        region: Binding<MKCoordinateRegion?>,
        onMapLongPress: @escaping (Coordinate) -> Void,
        onSelect: @escaping (Coordinate) -> Void
    ) {
        self.coordinates = coordinates
        self._region = region
        self.onMapLongPress = onMapLongPress
        self.onSelect = onSelect
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MKMapView {
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

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        update(coordinates: coordinates, in: mapView)
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlay(PathPolyline(coordinates))
    }

    public final class Coordinator: MapCoordinator<HazardSectionEditMap> {
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }

        public override func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            super.mapView(mapView, didSelect: view)
            guard let coordinate = view.annotation?.coordinate else { return }
            parent.onSelect(.fromCL(coordinate))
        }
    }
}
