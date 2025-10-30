//
//  PublicLocationsMap.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/05.
//

import UIKit
import MapKit
import SwiftUI

struct PublicLocationsMap: UIViewRepresentable {
    var items: [LocationInfo]
    var onTap: (LocationInfo)->Void
    @Binding var region: MKCoordinateRegion
    
    init(
        items: [LocationInfo],
        onTap: @escaping (LocationInfo) -> Void,
        region: Binding<MKCoordinateRegion>
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
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        updateFloatAnnotations(on: mapView, with: items)
        
        if region.center.latitude != mapView.region.center.latitude
            || region.center.longitude != mapView.region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }
    
    func updateFloatAnnotations(
        on mapView: MKMapView,
        with items: [LocationInfo]
    ) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? FloatCurrentAnnotation }
        let existingLocations = existingAnnotations.map { $0.location }

        // 削除
        let toRemove = existingAnnotations.filter { !items.contains($0.location) }
        mapView.removeAnnotations(toRemove)

        // 追加
        let toAdd = items.filter { !existingLocations.contains($0) }
        for location in toAdd {
            let annotation = FloatCurrentAnnotation(location: location)
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
            
            if let FloatCurrentAnnotation = annotation as? FloatCurrentAnnotation {
                return FloatAnnotationView.view(for: mapView, annotation: FloatCurrentAnnotation)
            }

            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            if let  annotation = view.annotation as? FloatCurrentAnnotation {
                parent.onTap(annotation.location)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}



