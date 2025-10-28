//
//  Segment.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Segment: Codable{
    let id: String
    let start: Coordinate
    let end: Coordinate
    var coordinates: [Coordinate]
    let isPassed: Bool
    init(id: String,start: Coordinate, end: Coordinate, coordinates: [Coordinate]? = nil, isPassed: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.coordinates = coordinates ?? [start, end]
        self.isPassed = isPassed
    }
}

extension Segment: Equatable {
}

extension Segment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Segment{
    static let sample = Self(id: UUID().uuidString, start: Coordinate.sample, end: Coordinate.sample)
}

struct Pair<Element: Equatable>: Equatable {
    let first: Element
    let second: Element
}
