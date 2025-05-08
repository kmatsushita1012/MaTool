//
//  PublicDistrict.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/25.
//

import Foundation

struct PublicDistrict: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let regionId: String
    let regionName: String
    let description: String?
    let base: Coordinate?
    let area: [Coordinate]
    let imagePath:String?
    let performances: [Performance]
}

extension PublicDistrict: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)  // ← IDだけでハッシュを決める
    }
}

extension PublicDistrict {
    func toModel() -> District {
        return District(
            id: self.id,
            name: self.name,
            regionId: self.regionId,
            description: self.description,
            base: self.base,
            area: self.area,
            imagePath: self.imagePath,
            performances: self.performances
        )
    }
}

extension PublicDistrict {
    static let sample = Self(id:"Johoku", name: "城北町",regionId: "kakegawa", regionName: "掛川祭", description: "省略",base: Coordinate.sample, area: [], imagePath:nil, performances: [Performance.sample])
}
