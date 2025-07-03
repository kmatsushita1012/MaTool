//
//  Point.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Point: Codable{
    let id: String
    var coordinate: Coordinate
    @NullEncodable var title: String? = nil
    @NullEncodable var description: String? = nil
    @NullEncodable var time: SimpleTime? = nil
    var isPassed: Bool = false
    var shouldExport: Bool = false
    
    init(id:String, coordinate: Coordinate, title: String?=nil, description: String?=nil, time: SimpleTime?=nil, isPassed: Bool = false, shouldExport: Bool = false) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.description = description
        self.time = time
        self.isPassed = isPassed
        self.shouldExport = shouldExport
    }
}

extension Point: Equatable {
    static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Point: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Point {
    static let sample = Self(id: UUID().uuidString, coordinate: Coordinate.sample)
}

