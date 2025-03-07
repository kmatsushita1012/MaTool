//
//  Share.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//
import Foundation

struct RouteSummary: Codable,Equatable{
    let id: UUID
    let date:SimpleDate
    let title: String
    init(id: UUID, date: SimpleDate, title: String) {
        self.id = id
        self.date = date
        self.title = title
    }
    
    static func == (lhs: RouteSummary, rhs: RouteSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Route: Codable,Equatable{
    let id: UUID
    let date:SimpleDate
    var title: String
    var description: String?
    var points: [Point]
    var segments: [Segment]
    var current: Location?
    var start: Time
    var goal: Time
    init(id: UUID,date: SimpleDate, title: String, points: [Point], segments: [Segment], current: Location?=nil, description: String?=nil, start: Time, goal: Time) {
        self.id = id
        self.points = points
        self.segments = segments
        self.current = current
        self.date = date
        self.title = title
        self.description = description
        self.start = start
        self.goal = goal
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Point: Codable, Equatable{
    let id: UUID
    let coordinate: Coordinate
    var title: String?
    var description: String?
    var time: Time?
    let isPassed: Bool
    init(id:UUID, coordinate: Coordinate, title: String?=nil, description: String?=nil, time: Time?=nil, isPassed: Bool = false) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.description = description
        self.time = time
        self.isPassed = isPassed
    }
    static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Segment: Codable,Equatable{
    let id: UUID
    let start: Coordinate
    let end: Coordinate
    var coordinates: [Coordinate]
    let isPassed: Bool
    init(id: UUID,start: Coordinate, end: Coordinate, coordinates: [Coordinate]? = nil, isPassed: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.coordinates = coordinates ?? [start, end]
        self.isPassed = isPassed
    }
    static func == (lhs: Segment, rhs: Segment) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Location: Codable{
    let coordinate: Coordinate
    let time: Time
}

struct Pair: Codable, Equatable{
    let id: UUID
    let point: Point
    let segment: Segment
    static func == (lhs: Pair, rhs: Pair) -> Bool {
        return false
    }
}
