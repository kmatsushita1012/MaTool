////
////  RoutePublicMapView.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI

struct RouteMap: UIViewRepresentable {
    var points: [Point]?
    var segments: [Segment]?
    var locations: [PublicLocation]?
    var pointTapped: (Point)->Void
    var locationTapped: (PublicLocation)->Void
    
    init(points: [Point]? = nil, segments: [Segment]? = nil, locations: [PublicLocation]? = nil, pointTapped: @escaping (Point) -> Void, locationTapped: @escaping (PublicLocation) -> Void) {
        self.points = points
        self.segments = segments
        self.locations = locations
        self.pointTapped = pointTapped
        self.locationTapped = locationTapped
    }
    
    init(points: [Point]? = nil, segments: [Segment]? = nil, location: PublicLocation? = nil, pointTapped: @escaping (Point) -> Void, locationTapped: @escaping (PublicLocation) -> Void) {
        self.points = points
        self.segments = segments
        self.locations = location.map { [$0] }
        self.pointTapped = pointTapped
        self.locationTapped = locationTapped
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // アノテーション追加
        if let points = self.points{
            for point in points {
                let annotation = PointAnnotation(point: point)
                annotation.coordinate = point.coordinate.toCL()
                mapView.addAnnotation(annotation)
            }
        }
        
        // ポリライン追加
        if let segments = self.segments{
            for segment in segments {
                let polyline = TappablePolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
                polyline.segment = segment // ユーザーデータに保持
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

        if !context.coordinator.hasSetRegion,
           let points = points,
           let first = points.first {
            let center = CLLocationCoordinate2D(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetRegion = true
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMap
        var hasSetRegion = false

        init(_ parent: RouteMap) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.point)
            } else if let  annotation = view.annotation as? LocationAnnotation {
                parent.locationTapped(annotation.location)
            }
        }
        
        

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tappablePolyline = overlay as? TappablePolyline {
                let renderer = MKPolylineRenderer(overlay: tappablePolyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                renderer.alpha = 0.8
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}


private class PointAnnotation: MKPointAnnotation {
    let point: Point
    init(point: Point) {
        self.point = point
        super.init()
        self.title = point.title
    }
}

private class TappablePolyline: MKPolyline {
    var segment: Segment? = nil
}

private class LocationAnnotation: MKPointAnnotation {
    let location: PublicLocation
    
    init(location: PublicLocation) {
        self.location = location
        super.init()
        self.title = location.districtId
    }
}
