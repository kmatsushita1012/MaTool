//
//  Extensions.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//
import MapKit
import Foundation
import SwiftUI


func filterPoints(_ route: PublicRoute)-> [Point] {
    var newPoints:[Point] = []
    if let firstPoint = route.points.first,
        !firstPoint.shouldExport {
        let tempFirst = Point(id: firstPoint.id, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
        newPoints.append(tempFirst)
    }
    newPoints.append(contentsOf: route.points[1..<(route.points.count - 1)].filter{ $0.shouldExport })
    if route.points.count >= 2,
       let lastPoint = route.points.last,
       !lastPoint.shouldExport {
        let tempLast = Point(id: lastPoint.id, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
        newPoints.append(tempLast)
    }
    return newPoints
}

func makeRegion(_ coordinates:[Coordinate],ratio :Double = 1.1) -> MKCoordinateRegion {
    let minLat = coordinates.map { $0.latitude }.min() ?? 0
    let maxLat = coordinates.map { $0.latitude }.max() ?? 0
    let minLon = coordinates.map { $0.longitude }.min() ?? 0
    let maxLon = coordinates.map { $0.longitude }.max() ?? 0

    let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )
    let latitudeDelta = (maxLat - minLat) * ratio
    let longitudeDelta = (maxLon - minLon) * ratio
    var span: MKCoordinateSpan
    if spanDelta > latitudeDelta || spanDelta > longitudeDelta {
        span = MKCoordinateSpan(
            latitudeDelta: spanDelta,
            longitudeDelta: spanDelta
        )
    } else {
        span = MKCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    }
    return MKCoordinateRegion(center: center, span: span)
}

func makeRegion(base: Coordinate?, spanDelta: CLLocationDegrees) -> MKCoordinateRegion? {
    if let base = base{
        return MKCoordinateRegion(
            center: base.toCL(),
            span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
        )
    }
    return nil
}


