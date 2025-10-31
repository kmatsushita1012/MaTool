//
//  DistrictSummary.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/12.
//

struct DistrictSummary: Codable, Equatable, Identifiable{
    let id: String
    let name: String
}

extension DistrictSummary: Hashable{
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension DistrictSummary {
    init(from district: District) {
        self.id = district.id
        self.name = district.name
    }
}

extension DistrictSummary{
    static let sample = Self(id: "Johoku", name: "城北町")
}

