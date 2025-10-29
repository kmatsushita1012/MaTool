//
//  EditableRoute.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/12.
//

import Foundation

struct Route: Codable, Equatable, Identifiable {
    let id: String
    let districtId: String
    var date:SimpleDate = .today
    var title: String = ""
    @NullEncodable var description: String?
    var points: [Point] = []
    var segments: [Segment] = []
    var start: SimpleTime
    var goal: SimpleTime
}

extension Route {
    
    func text(format: String) -> String {
        var result = ""
        var i = format.startIndex
        
        while i < format.endIndex {
            let char = format[i]
            
            let nextIndex = format.index(after: i)
            let hasNext = nextIndex < format.endIndex
            let nextChar = hasNext ? format[nextIndex] : nil

            switch char {
            case "T":
                result += title
            case "y":
                result += String(date.year)
            case "m":
                if nextChar == "2" {
                    result += String(format: "%02d", date.month)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(date.month)
                }
            case "d":
                if nextChar == "2" {
                    result += String(format: "%02d", date.day)
                    i = format.index(after: nextIndex)
                    continue
                } else {
                    result += String(date.day)
                }
            default:
                result += String(char)
            }

            i = format.index(after: i)
        }
        return result
    }
    
}

extension Route {
    static let sample = Route(
        id: UUID().uuidString,
        districtId: "Johoku",
        date: SimpleDate.sample,
        title: "午後",
        description: "準備中",
        points: [
            Point(id: UUID().uuidString,coordinate: Coordinate(latitude: 34.777681, longitude: 138.007029), title: "出発", time: SimpleTime(hour: 9, minute: 0)),
            Point(id: UUID().uuidString,coordinate: Coordinate(latitude: 34.778314, longitude: 138.008176), title: "到着", description: "お疲れ様です", time: SimpleTime(hour: 12, minute: 0))
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
