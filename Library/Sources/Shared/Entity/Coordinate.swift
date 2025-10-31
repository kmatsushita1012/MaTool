//
//  Coordinate.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//
import MapKit

public struct Coordinate: Entity {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}


public extension Coordinate {
    func toCL() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    static func fromCL(_ coordinate: CLLocationCoordinate2D)->Coordinate{
        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
