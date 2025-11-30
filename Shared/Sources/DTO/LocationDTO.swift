//
//  LocationDTO.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

//MARK: - FloatLocationGetDTO
public struct FloatLocationGetDTO: DTO{
    public let districtId: String
    public let districtName: String
    public let coordinate: Coordinate
    public let timestamp: Date
    
    public init(districtId: String, districtName: String, coordinate: Coordinate, timestamp: Date) {
        self.districtId = districtId
        self.districtName = districtName
        self.coordinate = coordinate
        self.timestamp = timestamp
    }
}

extension FloatLocationGetDTO: Identifiable {
    public var id: String {
        districtId
    }
}
