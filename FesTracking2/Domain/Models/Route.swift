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
    let title: String
    let description: String?
    let points: [Point]
    let segments: [Segment]
    let current: Point?
    let start: Time
    let goal: Time
    init(id: UUID, points: [Point], segments: [Segment], current: Point?=nil, date: SimpleDate, title: String, description: String?=nil,start: Time, goal: Time) {
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

struct Point: Codable{
    let coordinate: Coordinate
    let title: String?
    let description: String?
    let time: Time?
    let isPassed: Bool
    init(coordinate: Coordinate, title: String?=nil, description: String?=nil, time: Time?=nil, isPassed: Bool) {
        self.coordinate = coordinate
        self.title = title
        self.description = description
        self.time = time
        self.isPassed = isPassed
    }
}

struct Segment: Codable{
    let coordinates: [Coordinate]
    
    init(coordinates: [Coordinate]) {
        self.coordinates = coordinates
    }
}

struct Location: Codable{
    let coordinate: Coordinate
    let time: Time
    init(coordinate: Coordinate, time: Time) {
        self.coordinate = coordinate
        self.time = time
    }
}
