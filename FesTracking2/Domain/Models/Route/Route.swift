//
//  Route.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Route: Codable{
    let districtId: String
    let date:SimpleDate
    let title: String
    let description: String?
    let points: [Point]
    let segments: [Segment]
    let start: SimpleTime?
    let goal: SimpleTime?
    
    init(districtId: String, date: SimpleDate, title: String, points: [Point], segments: [Segment], description: String?=nil, start: SimpleTime?=nil, goal: SimpleTime?=nil) {
        self.districtId = districtId
        self.date = date
        self.title = title
        self.description = description
        self.points = points
        self.segments = segments
        self.start = start
        self.goal = goal
    }
}

extension Route: Equatable {
    static func == (lhs: Route, rhs: Route) -> Bool {
        return lhs.districtId == rhs.districtId && lhs.date == rhs.date && lhs.title == rhs.title
    }
}

extension Route {
    static let sample = Route(
        districtId: "Johoku",
        date: SimpleDate.sample,
        title: "午後",
        points: [
            Point(id: UUID(),coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "出発", time: SimpleTime(hour: 9, minute: 0),isPassed: true),
            Point(id: UUID(),coordinate: Coordinate(latitude: 34.778314, longitude: 138.008176), title: "到着", description: "お疲れ様です", time: SimpleTime(hour: 12, minute: 0),isPassed: true)
        ],
        segments: [
            Segment(id: UUID(), start: Coordinate(latitude: 34.777681, longitude: 138.007029), end: Coordinate(latitude: 34.778314, longitude: 138.008176), coordinates: [
                Coordinate(latitude: 34.777681, longitude: 138.007029),
                Coordinate(latitude: 34.777707, longitude: 138.008183),
                Coordinate(latitude: 34.778314, longitude: 138.008176)
            ], isPassed: true)
        ],
        description: "省略",
        start: SimpleTime.sample,
        goal: SimpleTime(
            hour:12,
            minute: 00
        )
    )
}
