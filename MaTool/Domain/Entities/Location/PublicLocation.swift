//
//  LocationInfo.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/25.
//

import Foundation

struct LocationInfo: Equatable, Codable{
    let districtId: String
    let districtName: String
    let coordinate: Coordinate
    let timestamp: Date
}

extension LocationInfo: Identifiable, Hashable {
    var id: String {
        districtId
    }
}

extension LocationInfo {
    static let sample = Self(districtId: "掛川祭_城北町",districtName: "城北町", coordinate: Coordinate.sample, timestamp: Date.sample)
}
