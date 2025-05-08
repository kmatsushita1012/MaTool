//
//  Region.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//


struct Region: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var description: String?
    var prefecture: String
    var city: String
    var spans: [Span] = []
    var imagePath:String?
}


extension Region {
    static let sample = Self(id: "kakegawamaturi", name: "掛川祭",description: "省略", prefecture: "静岡県", city: "掛川市", spans: [Span.sample])
}

