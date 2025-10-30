////
////  CustomMapView.swift
////  MaTool
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI

struct AdminRouteMapView: UIViewRepresentable {
    var points: [Point]
    var segments: [Segment]
    var onMapLongPress: (Coordinate) -> Void
    var pointTapped: (Point) -> Void
    var polylineTapped: (Segment) -> Void
    @Binding var region: MKCoordinateRegion?


    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // アノテーション追加
        for point in points {
            let annotation = PointAnnotation(point, type: .simple )
            annotation.coordinate = point.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }

        // ポリライン追加
        for segment in segments {
            let polyline = SegmentPolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
            polyline.segment = segment // ユーザーデータに保持
            mapView.addOverlay(polyline)
        }
        
        if let region = region, region.center.latitude != mapView.region.center.latitude || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminRouteMapView

        init(_ parent: AdminRouteMapView) {
            self.parent = parent
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
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.point)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tappablePolyline = overlay as? SegmentPolyline {
                let renderer = MKPolylineRenderer(overlay: tappablePolyline)
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
