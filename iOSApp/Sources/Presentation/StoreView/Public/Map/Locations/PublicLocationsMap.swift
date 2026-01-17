//
//  PublicLocationsMap.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import UIKit
import SwiftUI
import MapKit
import Shared

struct PublicLocationsMap: UIViewRepresentable {
    var locations: [FloatCurrentAnnotation]
    var onTap: (FloatCurrentAnnotation)->Void
    @Binding var region: MKCoordinateRegion
    
    init(
        _ locations: [FloatCurrentAnnotation],
        onTap: @escaping (FloatCurrentAnnotation) -> Void,
        region: Binding<MKCoordinateRegion>
    ) {
        self.locations = locations
        self.onTap = onTap
        self._region = region
    }
    
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
        updateFloatAnnotations(on: mapView, with: locations)
        
        if region.center.latitude != mapView.region.center.latitude
            || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }
    
    func updateFloatAnnotations(
        on mapView: MKMapView,
        with annotations: [FloatCurrentAnnotation]
    ) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? FloatCurrentAnnotation }

        // 削除
        let toRemove = existingAnnotations.filter { !locations.contains($0) }
        mapView.removeAnnotations(toRemove)

        // 追加
        let toAdd = annotations.filter { !existingAnnotations.contains($0) }
        for annotation in toAdd {
            mapView.addAnnotation(annotation)
        }
    }


    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicLocationsMap
        
        init(_ parent: PublicLocationsMap) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let annotation = annotation as? FloatCurrentAnnotation {
                return FloatAnnotationView.view(for: mapView, annotation: annotation)
            }

            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            if let  annotation = view.annotation as? FloatCurrentAnnotation {
                parent.onTap(annotation)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}



