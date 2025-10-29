//
//  AdminRouteExportMapView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/09.
//

import SwiftUI
import MapKit

struct AdminRouteExportMapView: UIViewRepresentable {
    var points: [Point]
    var segments: [Segment]
    @Binding var region: MKCoordinateRegion?
    @Binding var size: CGSize?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        if let region = region{
            mapView.setRegion(region, animated: false)
        }
        size = mapView.frame.size
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        // アノテーション追加
        for (index, point) in points.enumerated() {
            let annotation = PointAnnotation(point, type: .time(index) )
            annotation.coordinate = point.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }

        // ポリライン追加
        for segment in segments {
            let polyline = SegmentPolyline(coordinates: segment.coordinates.map({$0.toCL()}), count: segment.coordinates.count)
            polyline.segment = segment
            mapView.addOverlay(polyline)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminRouteExportMapView
        var hasSetRegion = false

        init(_ parent: AdminRouteExportMapView) {
            self.parent = parent
            
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
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }

}

