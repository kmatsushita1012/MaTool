//
//  FloatLocation.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

public struct FloatLocation: Entity{
    public let districtId: String
    public let coordinate: Coordinate
    public let timestamp: Date
    
    public init(districtId: String, coordinate: Coordinate, timestamp: Date) {
        self.districtId = districtId
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}

extension FloatLocation: Identifiable {
    public var id: String {
        districtId
    }
}
