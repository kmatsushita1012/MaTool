//
//  MapView.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import SwiftUI
import Shared
import MapKit

struct MapView: UIViewRepresentable {
    enum Style: Entity {
        case `public`
        case admin
        case edit
    }
    
    let style: Style
    let points: [PointEntry]
    let polyline: [Coordinate]
    let floats: [FloatEntry]
    let floatAnnotation: FloatAnnotation?
    @Binding var region: MKCoordinateRegion
    @Binding var size: CGSize?
    let pointTapped: (PointEntry)->Void
    let floatTapped: (FloatEntry)->Void
    let onLongPress: (Coordinate) -> Void
    
    private init(style: Style, points: [PointEntry], polyline: [Coordinate], floats: [FloatEntry] = [], floatAnnotation: FloatAnnotation? = nil, region: Binding<MKCoordinateRegion>, size: Binding<CGSize?>, pointTapped: @escaping (PointEntry) -> Void, floatTapped: @escaping (FloatEntry) -> Void, onLongPress: @escaping (Coordinate) -> Void) {
        self.style = style
        self.points = points
        self.polyline = polyline
        self.floats = floats
        self.floatAnnotation = floatAnnotation
        self._size = size
        self._region = region
        self.pointTapped = pointTapped
        self.floatTapped = floatTapped
        self.onLongPress = onLongPress
    }
    
    init(
        style: Style,
        points: [PointEntry] = [],
        floatAnnotation: FloatAnnotation? = nil,
        region: Binding<MKCoordinateRegion>,
        size: Binding<CGSize?> = .constant(nil),
        pointTapped: @escaping (PointEntry) -> Void = { _ in },
        floatTapped: @escaping (FloatEntry) -> Void = { _ in },
        onLongPress: @escaping (Coordinate) -> Void = { _ in }
    ) {
        self.init(style: style, points: points, polyline: points.map(\.coordinate), floatAnnotation: floatAnnotation, region: region, size: size, pointTapped: pointTapped, floatTapped: floatTapped, onLongPress: onLongPress)
    }
    
    init(
        style: Style,
        points: [PointEntry] = [],
        floats: [FloatEntry],
        region: Binding<MKCoordinateRegion>,
        size: Binding<CGSize?> = .constant(nil),
        pointTapped: @escaping (PointEntry) -> Void = { _ in },
        floatTapped: @escaping (FloatEntry) -> Void = { _ in },
        onLongPress: @escaping (Coordinate) -> Void = { _ in }
    ) {
        self.init(style: style, points: points, polyline: points.map(\.coordinate), floats: floats, region: region, size: size, pointTapped: pointTapped, floatTapped: floatTapped, onLongPress: onLongPress)
    }
   
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.showsUserLocation = true
        
        // 長押しジェスチャー追加
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        mapView.addGestureRecognizer(longPress)
        mapView.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [
            .restaurant,
            .nightlife
        ])
        mapView.showsCompass = false
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.updatePoints(from: points.filter(style: style))
        mapView.updatePolyline(polyline)
        mapView.updateFloats(from: floats)
        mapView.updateFloat(floatAnnotation)
        
        let epsilon: CLLocationDegrees = 0.00001
        let latDiff = abs(region.center.latitude - mapView.region.center.latitude)
        let lonDiff = abs(region.center.longitude - mapView.region.center.longitude)
        if latDiff > epsilon || lonDiff > epsilon {
            mapView.setRegion(region, animated: true)
        }
        
        if size != mapView.frame.size{
            size = mapView.frame.size
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
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
            if let FloatCurrentAnnotation = annotation as? FloatAnnotation {
                return FloatAnnotationView.view(for: mapView, annotation: FloatCurrentAnnotation)
            }
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 膨らみ防止
            if let annotation = view.annotation {
                mapView.deselectAnnotation(annotation, animated: false)
            }
            
            if let annotation = view.annotation as? PointAnnotation {
                parent.pointTapped(annotation.entry)
            } else if let annotation = view.annotation as? FloatCurrentAnnotation {
                parent.floatTapped(annotation.entry)
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
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onLongPress(Coordinate.fromCL(coordinate))
        }
    }
}

fileprivate extension Array where Element == PointEntry {
    func filter(style: MapView.Style) -> Self {
        switch style {
        case .public:
            self.filter{ $0.anchor != nil || $0.performance != nil }
        case .admin:
            self.filter{ $0.anchor != nil || $0.checkpoint != nil }
        case .edit:
            self
        }
    }
}

fileprivate extension MKMapView {
    func updatePoints(from entries: [PointEntry], stryle: PointAnnotation.Stryle = .simple){
        let existingAnnotations = annotations.compactMap { $0 as? PointAnnotation }

        let existingEntries = Set(existingAnnotations.map { $0.entry })
        let newEntries = Set(entries)

        // 削除対象
        let annotationsToRemove = existingAnnotations.filter {
            !newEntries.contains($0.entry)
        }

        // 追加対象
        let entriesToAdd = newEntries.subtracting(existingEntries)

        removeAnnotations(annotationsToRemove)

        let annotationsToAdd = entriesToAdd.map { PointAnnotation($0, style: stryle) }
        addAnnotations(annotationsToAdd)
    }
    
    func updatePolyline(_ coordinates: [Coordinate]) {
        let oldPolylines = overlays.compactMap { $0 as? PathPolyline }
        addOverlay(PathPolyline(coordinates))
        removeOverlays(oldPolylines)
    }
    
    func updateFloats(from entries: [FloatEntry]){
        let existingAnnotations = annotations.compactMap { $0 as? FloatCurrentAnnotation }

        let existingEntries = Set(existingAnnotations.map { $0.entry })
        let newEntries = Set(entries)

        // 削除対象
        let annotationsToRemove = existingAnnotations.filter {
            !newEntries.contains($0.entry)
        }

        // 追加対象
        let entriesToAdd = newEntries.subtracting(existingEntries)

        removeAnnotations(annotationsToRemove)

        let annotationsToAdd = entriesToAdd.map { FloatCurrentAnnotation($0) }
        addAnnotations(annotationsToAdd)
    }
    
    func updateFloat(_ float: FloatAnnotation?) {
        let old = annotations.compactMap { $0 as? FloatAnnotation }
        let toRemove = old.filter { $0 != float }
        if let float, !old.contains(where: { $0 == float }) {
            removeAnnotations(toRemove)
            addAnnotation(float)
        } else {
            removeAnnotations(toRemove)
        }
    }
}

extension MapView: Equatable {
    static func == (lhs: MapView, rhs: MapView) -> Bool {
        return lhs.style == rhs.style &&
        lhs.points == rhs.points &&
        lhs.polyline == rhs.polyline &&
        lhs.floats == rhs.floats &&
        lhs.floatAnnotation == rhs.floatAnnotation &&
        lhs.region == rhs.region
    }
}
