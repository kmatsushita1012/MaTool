//
//  District.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct District: Codable, Equatable, Identifiable{
    let id: String
    var name: String
    let regionId: String
    var description: String? = nil
    var base: Coordinate? = nil
    var area: [Coordinate] = []
    var imagePath:String? = nil
    var performances: [Performance] = []
    var visibility: Visibility
}


extension District: Hashable{
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension District {
    static let sample = Self(id: "掛川祭_城北町", name: "城北町", regionId: "掛川祭_年番本部", description: "省略", performances: [Performance.sample], visibility: .all)
}
