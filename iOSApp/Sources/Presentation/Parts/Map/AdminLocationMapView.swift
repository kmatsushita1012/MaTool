//
//  AdminLocationMapView.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/18.
//

import UIKit
import MapKit
import SwiftUI

struct AdminLocationMap: UIViewRepresentable {
    var showsUserLocation: Bool = false
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = showsUserLocation
        mapView.setUserTrackingMode(showsUserLocation ? .follow : .none, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation
        mapView.setUserTrackingMode(showsUserLocation ? .follow : .none, animated: false)
    }
}
