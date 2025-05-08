//
//  PublicLocation.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/25.
//

import Foundation

struct PublicLocation: Codable{
    let districtId: String
    let districtName: String
    let coordinate: Coordinate
    let timestamp: Date
}

extension PublicLocation: Equatable {}

extension PublicLocation {
    static let sample = Self(districtId: "johoku",districtName: "城北町", coordinate: Coordinate.sample, timestamp: Date.sample)
}
