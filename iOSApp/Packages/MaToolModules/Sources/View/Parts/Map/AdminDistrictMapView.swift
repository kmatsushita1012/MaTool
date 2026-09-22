import iOSShared
////
////  AdminDistrictMapView.swift
////  MaTool
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI
import Shared

public struct AdminDistrictMap: UIViewRepresentable {
    var coordinates: [Coordinate]?
    var isShownPolygon: Bool
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void

    public init(
        coordinates: [Coordinate]?,
        isShownPolygon: Bool,
        region: Binding<MKCoordinateRegion?>,
        onMapLongPress: @escaping (Coordinate) -> Void
    ) {
        self.coordinates = coordinates
        self.isShownPolygon = isShownPolygon
        self._region = region
        self.onMapLongPress = onMapLongPress
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        
        return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        guard let coordinates = coordinates else { return }
        
        for coordinate in coordinates {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate.toCL()
            mapView.addAnnotation(annotation)
        }
        
        if isShownPolygon && coordinates.count >= 3 {
            let coordinates = coordinates.map { $0.toCL() }
            let polygonOverlay = MKPolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polygonOverlay)
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminDistrictMap

        public init(_ parent: AdminDistrictMap) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }
        
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}
