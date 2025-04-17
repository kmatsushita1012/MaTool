//
//  Point.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Point: Codable{
    let id: UUID
    let coordinate: Coordinate
    var title: String?
    var description: String?
    var time: SimpleTime?
    let isPassed: Bool
    
    init(id:UUID, coordinate: Coordinate, title: String?=nil, description: String?=nil, time: SimpleTime?=nil, isPassed: Bool = false) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.description = description
        self.time = time
        self.isPassed = isPassed
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
    static let sample = Self(id: UUID(), coordinate: Coordinate.sample)
}

