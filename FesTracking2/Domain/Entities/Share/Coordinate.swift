//
//  Coordinate.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

struct Coordinate: Codable{
    let latitude: Double
    let longitude: Double
}

extension Coordinate: Equatable{
    static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension Coordinate {
    static let sample = Self(latitude: 34.777805, longitude: 138.007211)
}


