//
//  RegionSummary.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/11.
//

struct RegionSummary: Codable, Equatable{
    let id: String
    let name: String
}

extension RegionSummary: Identifiable {}

extension RegionSummary{
    static let sample = Self(id: "kakegawamaturi", name: "掛川祭")
}

