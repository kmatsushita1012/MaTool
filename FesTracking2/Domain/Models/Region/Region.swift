//
//  Region.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

struct Region: Codable{
    let id: String
    let name: String
    let description: String?
    let prefecture: String
    let city: String
    let dates: [SimpleDate]
    let imagePath:String?
    
    init(id: String, name: String, description: String?=nil, prefecture: String, city: String, dates: [SimpleDate], imagePath: String?=nil) {
        self.id = id
        self.name = name
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.dates = dates
        self.imagePath = imagePath
    }
}

extension Region: Equatable {
    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.id == rhs.id
    }
}



extension Region {
    static let sample = Self(id: "kakegawamaturi", name: "掛川祭",description: "省略", prefecture: "静岡県", city: "掛川市", dates: [SimpleDate.sample])
}

