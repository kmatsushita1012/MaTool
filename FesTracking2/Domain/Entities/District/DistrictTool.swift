//
//  DistrictTool.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/05.
//

struct DistrictTool: Codable, Equatable {
  let districtId: String
  let districtName: String
  let regionId: String
  let regionName: String
  let performances: [Performance]
  let base: Coordinate
  let spans: [Span]
}

extension DistrictTool {
    static let sample = DistrictTool(
        districtId: "掛川祭_城北町",
        districtName: "城北町",
        regionId: "掛川祭_年番本部",
        regionName: "年番本部",
        performances: [Performance.sample],
        base: Coordinate.sample,
        spans: [Span.sample])
}
