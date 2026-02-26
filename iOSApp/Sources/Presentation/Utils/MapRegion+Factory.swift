//
//  PresentationUtils.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/08.
//

import Foundation
import MapKit
import Shared

func makeRegion(_ coordinates: [Coordinate], ratio: Double = 1.1) -> MKCoordinateRegion {
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
    let span = MKCoordinateSpan(
        latitudeDelta: spanDelta > latitudeDelta ? spanDelta : latitudeDelta,
        longitudeDelta: spanDelta > longitudeDelta ? spanDelta : longitudeDelta
    )

    return MKCoordinateRegion(center: center, span: span)
}

func makeRegion(origin: Coordinate, spanDelta: CLLocationDegrees) -> MKCoordinateRegion {
    return MKCoordinateRegion(
        center: origin.toCL(),
        span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
    )
}

func makeRegion(_ points: [Point], ratio: Double = 1.1) -> MKCoordinateRegion {
    makeRegion(points.map(\.coordinate))
}

func makeRegion(points: [Point], origin: Coordinate, spanDelta: CLLocationDegrees) -> MKCoordinateRegion {
    if !points.isEmpty {
        makeRegion(points)
    } else {
        makeRegion(origin: origin, spanDelta: spanDelta)
    }
}

func makeRegion(
    points: [Point], location: FloatLocation?, origin: Coordinate, spanDelta: CLLocationDegrees
) -> MKCoordinateRegion {
    if let location {
        return makeRegion(origin: location.coordinate, spanDelta: spanDelta)
    } else if !points.isEmpty {
        return makeRegion(points.map { $0.coordinate })
    } else {
        return makeRegion(origin: origin, spanDelta: spanDelta)
    }
}

func makeRegion(
    points: [Point], location: FloatLocation?, origin: Coordinate?, spanDelta: CLLocationDegrees
) -> MKCoordinateRegion? {
    if let location {
        return makeRegion(origin: location.coordinate, spanDelta: spanDelta)
    } else if !points.isEmpty {
        return makeRegion(points.map { $0.coordinate })
    } else if let origin {
        return makeRegion(origin: origin, spanDelta: spanDelta)
    } else {
        return nil
    }
}

func makeRegion(locations: [FloatLocation], origin: Coordinate) -> MKCoordinateRegion {
    if !locations.isEmpty {
        return makeRegion(locations.map { $0.coordinate })
    } else {
        return makeRegion(origin: origin, spanDelta: spanDelta)
    }
}
