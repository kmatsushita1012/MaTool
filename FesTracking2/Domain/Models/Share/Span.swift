//
//  Span.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

import Foundation

struct Span: Codable{
    let id: String
    let start: DateTime
    let end: DateTime
}

extension Span: Equatable{
    static func == (lhs: Span, rhs: Span) -> Bool {
        return  lhs.start == rhs.start && lhs.end == rhs.end
    }
}

extension Span: Identifiable{}

extension Span: Comparable{
    static func < (lhs: Span, rhs: Span) -> Bool {
        return lhs.start < rhs.start
    }
}

extension Span {
    static let sample = Self(id: UUID().uuidString, start: DateTime.sample, end: DateTime.sample)
}

extension Span {
    var text: String {
        let startDate = start.date
        let endDate = end.date
        let startTime = start.time
        let endTime = end.time


        if startDate == endDate {
            return "\(startDate.text(year:false))  \(startTime.text)〜\(endTime.text)"
        } else {
            return "\(startDate.text(year:false))  \(startTime.text)〜\(startDate.text(year:false))  \(endTime.text))"
        }
    }
}
