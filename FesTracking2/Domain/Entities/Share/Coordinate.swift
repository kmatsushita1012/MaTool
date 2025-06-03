//
//  Coordinate.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

struct Coordinate: Codable, Equatable, Hashable{
    let latitude: Double
    let longitude: Double
}


extension Coordinate {
    static let sample = Self(latitude: 34.777805, longitude: 138.007211)
}


