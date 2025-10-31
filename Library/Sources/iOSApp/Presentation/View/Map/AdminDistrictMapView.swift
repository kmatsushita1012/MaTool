////
////  CustomMapView.swift
////  MaTool
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI
import Shared

struct AdminDistrictMap: UIViewRepresentable {
    var coordinates: [Coordinate]?
    var isShownPolygon: Bool
    @Binding var region: MKCoordinateRegion?
    var onMapLongPress: (Coordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
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

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminDistrictMap

        init(_ parent: AdminDistrictMap) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

