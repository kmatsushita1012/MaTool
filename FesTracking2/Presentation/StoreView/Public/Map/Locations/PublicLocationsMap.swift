//
//  PublicLocationsMap.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/05.
//

import UIKit
import MapKit
import SwiftUI

struct PublicLocationsMap: UIViewRepresentable {
    var items: [LocationInfo]
    var onTap: (LocationInfo)->Void
    @Binding var region: MKCoordinateRegion?
    
    init(
        items: [LocationInfo],
        onTap: @escaping (LocationInfo) -> Void,
        region: Binding<MKCoordinateRegion?>
    ) {
        self.items = items
        self.onTap = onTap
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
        
        //ロケーション追加
        for location in items {
            let annotation = LocationAnnotation(location: location)
            annotation.coordinate = location.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }
        
        if let region = region,
            region.center.latitude != mapView.region.center.latitude
            || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicLocationsMap
        
        init(_ parent: PublicLocationsMap) {
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
            if let  annotation = view.annotation as? LocationAnnotation {
                parent.onTap(annotation.location)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}



