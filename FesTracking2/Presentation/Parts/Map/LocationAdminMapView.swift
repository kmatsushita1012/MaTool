//
//  LocationAdminMapView.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/18.
//

import UIKit
import MapKit
import SwiftUI

struct LocationAdminMapView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow // 現在地を追跡
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 現在地が取得できていれば、その周囲を表示範囲として設定
        if let userLocation = mapView.userLocation.location {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // ズームレベルを調整
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationAdminMapView
        
        init(_ parent: LocationAdminMapView) {
            self.parent = parent
        }
    }
}

