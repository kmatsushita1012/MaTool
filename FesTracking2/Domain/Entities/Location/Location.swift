//
//  Location.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Location: Codable, Equatable, Hashable{
    let districtId: String
    let coordinate: Coordinate
    let timestamp: Date
}

extension Location: Identifiable {
    var id: String {
        districtId
    }
}

extension Location {
    static let sample = Self(districtId: "掛川祭_城北町", coordinate: Coordinate.sample, timestamp: Date.sample)
}


