//
//  DistrictSummary.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/12.
//

struct DistrictSummary: Codable, Equatable{
    let id: String
    let name: String
    let regionId: String
}

extension DistrictSummary: Identifiable {}

extension DistrictSummary{
    static let sample = Self(id: "johoku", name: "城北町", regionId: "kakegawa")
}

