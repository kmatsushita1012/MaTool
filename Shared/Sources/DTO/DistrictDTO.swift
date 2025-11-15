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
    public let regionId: String
    public let regionName: String
    public let milestones: [Information]
    public let base: Coordinate
    public let spans: [Span]
}
