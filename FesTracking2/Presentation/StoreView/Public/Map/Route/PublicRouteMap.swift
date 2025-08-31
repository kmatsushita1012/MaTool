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
    
    let points: [Point]?
    let polylines: [Pair<Point>]?
    let float: FloatAnnotationProtocol?
    @Binding var region: MKCoordinateRegion
    let pointTapped: (Point)->Void
    let locationTapped: ()->Void
   
    
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
        let epsilon: CLLocationDegrees = 0.00001
        let latDiff = abs(region.center.latitude - mapView.region.center.latitude)
        let lonDiff = abs(region.center.longitude - mapView.region.center.longitude)
        if latDiff > epsilon || lonDiff > epsilon {
            mapView.setRegion(region, animated: true)
        }
        
        updatePointAnnotations(mapView: mapView, points: points?.map{ $0.annotation() })
        updatePolyline(mapView: mapView, polylines: polylines?.map{ $0.polyline })
        updateFloatAnnotation(mapView: mapView, float: float)
    }
    
    //MARK: - Update
    func updatePointAnnotations(mapView: MKMapView, points: [PointAnnotation]?) {
        let oldAnnotations = mapView.annotations.compactMap { $0 as? PointAnnotation }
        let newPoints = points ?? []
        
        for point in newPoints where !oldAnnotations.contains(where: { $0 == point }) {
            mapView.addAnnotation(point)
        }
        let toRemove = oldAnnotations.filter { !newPoints.contains($0) }
        mapView.removeAnnotations(toRemove)
    }
    
    func updatePolyline(mapView: MKMapView, polylines: [PathPolyline]?) {
        let oldPolylines = mapView.overlays.compactMap { $0 as? PathPolyline }
        let newPolylines = polylines ?? []
        for polyline in newPolylines where !oldPolylines.contains(where: { $0 == polyline }) {
            mapView.addOverlay(polyline)
        }
        let toRemovePoly = oldPolylines.filter { polyline in
            return !newPolylines.contains(polyline)
        }
        mapView.removeOverlays(toRemovePoly)
    }
    
    func updateFloatAnnotation(mapView: MKMapView, float: FloatAnnotationProtocol?) {
        let old = mapView.annotations.compactMap { $0 as? FloatAnnotationProtocol }
        if let float, !old.contains(where: { $0 === float }) {
            mapView.addAnnotation(float)
        }
        let toRemove = old.filter { $0 !== float }
        mapView.removeAnnotations(toRemove)
    }


    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PublicRouteMap
        
        init(_ parent: PublicRouteMap) {
            self.parent = parent
        }
        
        //MARK: - MKMapViewDelegate
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            if let pointAnnotation = annotation as? PointAnnotation {
                return PointAnnotationView.view(for: mapView, annotation: pointAnnotation)
            }
            if let floatAnnotation = annotation as? FloatAnnotationProtocol {
                return FloatAnnotationView.view(for: mapView, annotation: floatAnnotation)
            }
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 膨らみ防止
            if let annotation = view.annotation {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.point)
            } else if view.annotation is FloatAnnotation {
                parent.locationTapped()
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? PathPolyline {
                return polyline.renderer()
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

extension PublicRouteMap: Equatable {
    static func == (lhs: PublicRouteMap, rhs: PublicRouteMap) -> Bool {
        lhs.points == rhs.points &&
        lhs.polylines == rhs.polylines &&
        lhs.float === rhs.float &&
        lhs.region == rhs.region
    }
}
