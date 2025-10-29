//
//  Coordinate.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//
import MapKit

struct Coordinate: Codable, Equatable, Hashable{
    let latitude: Double
    let longitude: Double
}


extension Coordinate {
    static let sample = Self(latitude: 34.777805, longitude: 138.007211)
}

extension Coordinate {
    func toCL()->CLLocationCoordinate2D{
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    static func fromCL(_ coordinate: CLLocationCoordinate2D)->Coordinate{
        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
