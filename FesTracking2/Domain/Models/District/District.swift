//
//  District.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct District: Codable{
    let id: String
    let name: String
    let regionId: String
    var description: String? = nil
    var base: Coordinate? = nil
    var area: [Coordinate] = []
    var imagePath:String? = nil
    var performances: [Performance] = []
}

extension District: Equatable{
    static func == (lhs: District, rhs: District) -> Bool {
        return lhs.id == rhs.id
    }
}

extension District {
    static let sample = Self(id: UUID().uuidString, name: "城北町", regionId: "kakegawa", description: "省略",performances: [Performance.sample])
}
