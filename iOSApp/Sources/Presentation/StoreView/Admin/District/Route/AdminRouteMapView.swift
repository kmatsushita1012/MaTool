//
//  AdminRouteMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/01.
//

import UIKit
import MapKit
import SwiftUI
import Shared

struct AdminRouteMapView: UIViewRepresentable {
    var points: [Point]
    var onMapLongPress: (Coordinate) -> Void
    var pointTapped: (Point) -> Void
    @Binding var region: MKCoordinateRegion?
    @Binding var size: CGSize?


    func makeCoordinator() -> Coordinator {
        Coordinator(self, points: Binding(get: { self.points }, set: { _ in }))
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 長押しジェスチャー追加
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        mapView.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [
            .restaurant,
            .nightlife
        ])
        mapView.showsCompass = false
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        size = mapView.frame.size
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // アノテーション追加
//        for (index, point) in filter.apply(to: route).enumerated() {
//            let type: PointAnnotation.TitleType = filter == .export ? .time(index) : .simple
//            let annotation = PointAnnotation(point, type: type)
//            annotation.coordinate = point.coordinate.toCL()
//            mapView.addAnnotation(annotation)
//        }
        
        let coordinates = points.map { $0.coordinate.toCL() }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        if let region = region, region.center.latitude != mapView.region.center.latitude || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        if size != mapView.frame.size{
            size = mapView.frame.size
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminRouteMapView
        var points: Binding<[Point]>

        init(_ parent: AdminRouteMapView, points: Binding<[Point]>) {
            self.parent = parent
            self.points = points
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // 現在地はデフォルトのまま
            }
            let identifier = "AnnotationView"

            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.displayPriority = .required
            if #available(iOS 11.0, *) {
                (annotationView as? MKMarkerAnnotationView)?.clusteringIdentifier = nil
            }
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.canShowCallout = true
            }
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? PointAnnotation,
               let point = points.wrappedValue.first(matching: annotation.point.id) {
                parent.pointTapped(point)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(overlay: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                renderer.alpha = 0.8
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
    }
}
