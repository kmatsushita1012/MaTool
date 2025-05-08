//
//  Location.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Location: Codable{
    let districtId: String
    let coordinate: Coordinate
    let timestamp: Date
}

extension Location: Equatable {
    static func == (lhs: Location, rhs: Location) -> Bool {
        return lhs.districtId == rhs.districtId && lhs.timestamp == rhs.timestamp
    }
}

extension Location {
    static let sample = Self(districtId: "johoku", coordinate: Coordinate.sample, timestamp: Date.sample)
}


