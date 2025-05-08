////
////  CustomMapView.swift
////  FesTracking2
////
////  Created by 松下和也 on 2025/04/08.
////
import UIKit
import MapKit
import SwiftUI

struct RouteAdminMap: UIViewRepresentable {
    var points: [Point]
    var segments: [Segment]

    var onMapLongPress: (Coordinate) -> Void
    var pointTapped: (Point) -> Void
    var polylineTapped: (Segment) -> Void
    @Binding var mapViewRef: MKMapView?
    
    init(
        points: [Point],
        segments: [Segment],
        onMapLongPress: @escaping (Coordinate) -> Void = { _ in },
        pointTapped: @escaping (Point) -> Void = { _ in },
        polylineTapped: @escaping (Segment) -> Void = { _ in },
        mapViewRef: Binding<MKMapView?> = .constant(nil)
    ) {
        self.points = points
        self.segments = segments
        self.onMapLongPress = onMapLongPress
        self.pointTapped = pointTapped
        self.polylineTapped = polylineTapped
        self._mapViewRef = mapViewRef
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 長押しジェスチャー追加
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        
        DispatchQueue.main.async {
            self.mapViewRef = mapView
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // アノテーション追加
        for point in points {
            let annotation = PointAnnotation(point: point)
            annotation.coordinate = point.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }

        // ポリライン追加
        for segment in segments {
            let polyline = TappablePolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
            polyline.segment = segment // ユーザーデータに保持
            mapView.addOverlay(polyline)
        }

        if !context.coordinator.hasSetRegion, let first = points.first {
            let center = CLLocationCoordinate2D(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            mapView.setRegion(region, animated: false)
            context.coordinator.hasSetRegion = true
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteAdminMap
        var hasSetRegion = false

        init(_ parent: RouteAdminMap) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapLongPress(Coordinate.fromCL(coordinate))
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.point)
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


        func mapView(_ mapView: MKMapView, didSelect overlay: MKOverlay) {
            if let polyline = overlay as? TappablePolyline,
               let segment = polyline.segment{
                parent.polylineTapped(segment)
            }
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
