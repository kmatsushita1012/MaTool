//
//  PublicDistrictMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/29.
//

import UIKit
import MapKit
import SwiftUI

struct PublicDistrictMapView: UIViewRepresentable {
    var base: Coordinate?
    var area: [Coordinate]
    @Binding var region: MKCoordinateRegion?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        
        if let region = region {
            mapView.setRegion(region, animated: false)
        }
        
        if let base {
            let annotation = MKPointAnnotation()
            annotation.title = "会所"
            annotation.coordinate = base.toCL()
            mapView.addAnnotation(annotation)
        }
        
        let coordinates = area.map { $0.toCL() }
        let polygonOverlay = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygonOverlay)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {}
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicDistrictMapView

        init(_ parent: PublicDistrictMapView) {
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

