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
}

extension FloatLocationGetDTO: Identifiable {
    public var id: String {
        districtId
    }
}
