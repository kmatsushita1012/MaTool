//
//  PublicRouteMap.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/05.
//

import UIKit
import MapKit
import SwiftUI

struct PublicRouteMap: UIViewRepresentable {
    var points: [Point]?
    var segments: [Segment]?
    var location: LocationInfo?
    var pointTapped: (Point)->Void
    var locationTapped: ()->Void
    @Binding var region: MKCoordinateRegion
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // アノテーション追加
        if let points {
            for point in points {
                let annotation = PointAnnotation(point, type: .simple )
                annotation.coordinate = point.coordinate.toCL()
                mapView.addAnnotation(annotation)
            }
        }
        
        // ポリライン追加
        if let segments{
            for segment in segments {
                let polyline = SegmentPolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
                polyline.segment = segment
                mapView.addOverlay(polyline)
            }
        }
        
        //ロケーション追加
        if let location {
            let annotation = FloatAnnotation(location: location)
            annotation.coordinate = location.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }
        
        let epsilon: CLLocationDegrees = 0.00001
        let latDiff = abs(region.center.latitude - mapView.region.center.latitude)
        let lonDiff = abs(region.center.longitude - mapView.region.center.longitude)

        if latDiff > epsilon || lonDiff > epsilon {
            mapView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicRouteMap
        
        init(_ parent: PublicRouteMap) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            if let pointAnnotation = annotation as? PointAnnotation {
                return PointAnnotationView.view(for: mapView, annotation: pointAnnotation)
            }

            if let floatAnnotation = annotation as? FloatAnnotation {
                return FloatAnnotationView.view(for: mapView, annotation: floatAnnotation)
            }

            return nil
        }

        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.point)
            } else if view.annotation is FloatAnnotation {
                parent.locationTapped()
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SegmentPolyline {
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



