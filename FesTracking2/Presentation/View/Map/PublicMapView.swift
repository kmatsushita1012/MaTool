////
////  RoutePublicMapView.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI

struct PublicMapView: UIViewRepresentable {
    var points: [Point]?
    var segments: [Segment]?
    var locations: [PublicLocation]?
    var pointTapped: (Point)->Void
    var locationTapped: (PublicLocation)->Void
    @Binding var region: MKCoordinateRegion?
    
    init(locations: [PublicLocation]? = nil, locationTapped: @escaping (PublicLocation) -> Void, region: Binding<MKCoordinateRegion?>) {
        self.locations = locations
        self.pointTapped = { _ in }
        self.locationTapped = locationTapped
        self._region = region
    }
    
    init(points: [Point]? = nil, segments: [Segment]? = nil, location: PublicLocation? = nil, pointTapped: @escaping (Point) -> Void, locationTapped: @escaping (PublicLocation) -> Void, region: Binding<MKCoordinateRegion?>) {
        self.points = points
        self.segments = segments
        self.locations = location.map { [$0] }
        self.pointTapped = pointTapped
        self.locationTapped = locationTapped
        self._region = region
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // アノテーション追加
        if let points = self.points{
            for point in points {
                let annotation = PointAnnotation(point, type: .simple )
                annotation.coordinate = point.coordinate.toCL()
                mapView.addAnnotation(annotation)
            }
        }
        
        // ポリライン追加
        if let segments = self.segments{
            for segment in segments {
                let polyline = SegmentPolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
                polyline.segment = segment 
                mapView.addOverlay(polyline)
            }
        }
        
        //ロケーション追加
        if let locations = locations {
            for location in locations {
                let annotation = LocationAnnotation(location: location)
                annotation.coordinate = location.coordinate.toCL()
                mapView.addAnnotation(annotation)
            }
        }
        
        if let region = region,
            region.center.latitude != mapView.region.center.latitude
            || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicMapView
        
        init(_ parent: PublicMapView) {
            self.parent = parent
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
            } else if let  annotation = view.annotation as? LocationAnnotation {
                parent.locationTapped(annotation.location)
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



