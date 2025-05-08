//
//  Performance.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/17.
//

import Foundation

struct Performance: Codable, Equatable, Identifiable {
    let id: String
    var name: String = ""
    var performer: String = ""
    var description: String?
}

extension Performance {
    static let sample = Self(id: UUID().uuidString,name:"ぽんぽこにゃ",performer: "小学校1,2年生", description: nil)
}
