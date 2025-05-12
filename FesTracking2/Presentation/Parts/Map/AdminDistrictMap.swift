////
////  CustomMapView.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI

struct AdminDistrictMap: UIViewRepresentable {
    var coordinates: [Coordinate]?
    var isShownPolygon: Bool

    var onMapLongPress: (Coordinate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 長押しジェスチャー追加
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        guard let coordinates = coordinates else { return }
        // アノテーション追加
        for coordinate in coordinates {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate.toCL()
            mapView.addAnnotation(annotation)
        }

        // ポリゴン追加
        if isShownPolygon && coordinates.count >= 3 {
            let coordinates = coordinates.map { $0.toCL() }
            let polygonOverlay = MKPolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polygonOverlay)
        }
        
        if !context.coordinator.hasSetRegion, let first = coordinates.first {
            let center = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetRegion = true
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminDistrictMap
        var hasSetRegion = false

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
    }
}

