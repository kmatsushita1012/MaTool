//
//  DistrictDTO.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/31.
//

// MARK: - DistrictTool
public struct DistrictTool: DTO {
    public let districtId: String
    public let districtName: String
    public let festivalId: String
    public let festivalName: String
    public let checkpoints: [Checkpoint]
    public let base: Coordinate
    public let periods: [Period]
    
    public init(districtId: String, districtName: String, festivalId: String, festivalName: String, checkpoints: [Checkpoint], base: Coordinate, periods: [Period]) {
        self.districtId = districtId
        self.districtName = districtName
        self.festivalId = festivalId
        self.festivalName = festivalName
        self.checkpoints = checkpoints
        self.base = base
        self.periods = periods
    }
}

public struct DistrictCreateDTO: DTO {
    public let name: String
    public let email: String
    
    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}
