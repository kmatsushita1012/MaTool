//
//  Coordinate.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//


public struct Coordinate: Entity {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}


