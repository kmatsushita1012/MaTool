//
//  Region.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//


struct Region: Codable, Equatable, Identifiable, Hashable {
    let id: String
    var name: String
    var subname: String
    var description: String?
    var prefecture: String
    var city: String
    var spans: [Span] = []
    var imagePath:String?
}


extension Region {
    static let sample = Self(id: "掛川祭_年番本部", name: "掛川祭", subname: "年番本部", description: "省略", prefecture: "静岡県", city: "掛川市", spans: [Span.sample])
}

