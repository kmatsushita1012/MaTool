//
//  EditableRoute.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/12.
//

import Foundation

struct Route:Codable, Equatable {
    let districtId: String
    var date:SimpleDate = .today
    var title: String = ""
    var visibility: Visibility = .all
    var description: String?
    var points: [Point] = []
    var segments: [Segment] = []
    var start: SimpleTime?
    var goal: SimpleTime?
}


extension Route {
    static let sample = Route(
        districtId: "Johoku",
        date: SimpleDate.sample,
        title: "午後",
        visibility: .all,
        description: "準備中",
        points: [
            Point(id: UUID().uuidString,coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "出発", time: SimpleTime(hour: 9, minute: 0),isPassed: true),
            Point(id: UUID().uuidString,coordinate: Coordinate(latitude: 34.778314, longitude: 138.008176), title: "到着", description: "お疲れ様です", time: SimpleTime(hour: 12, minute: 0),isPassed: true)
        ],
        segments: [
            Segment(id: UUID().uuidString, start: Coordinate(latitude: 34.777681, longitude: 138.007029), end: Coordinate(latitude: 34.778314, longitude: 138.008176), coordinates: [
                Coordinate(latitude: 34.777681, longitude: 138.007029),
                Coordinate(latitude: 34.777707, longitude: 138.008183),
                Coordinate(latitude: 34.778314, longitude: 138.008176)
            ], isPassed: true)
        ],
        start: SimpleTime.sample,
        goal: SimpleTime(
            hour:12,
            minute: 00
        )
    )
}
