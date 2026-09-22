import iOSShared
//
//  AdminLocationMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import UIKit
import MapKit
import SwiftUI
import Shared

public struct AdminLocationMap: UIViewRepresentable {
    var location: FloatLocation?

    public init(location: FloatLocation?) {
        self.location = location
    }
    
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow // 現在地を追跡
        mapView.delegate = context.coordinator
        return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        // 現在地が取得できていれば、その周囲を表示範囲として設定
        if let userLocation = mapView.userLocation.location {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta) // ズームレベルを調整
            )
            mapView.setRegion(region, animated: true)
        }
        
        if let location = location {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate.toCL()
            mapView.addAnnotation(annotation)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AdminLocationMap
        
        public init(_ parent: AdminLocationMap) {
            self.parent = parent
        }
    }
}
