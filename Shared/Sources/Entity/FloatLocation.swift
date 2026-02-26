//
//  FloatLocation.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation
import SQLiteData

@Table public struct FloatLocation: Entity, Identifiable {
    public let id: String
    public let districtId: String
    @Column(as: Coordinate.JSONRepresentation.self)
    public let coordinate: Coordinate
    public let timestamp: Date
    
    public init(id: String, districtId: District.ID, coordinate: Coordinate, timestamp: Date = .now) {
        self.id = id
        self.districtId = districtId
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}
