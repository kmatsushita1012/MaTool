//
//  Span.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/08.
//

struct Span: Codable{
    let start: DateTime
    let end: DateTime
}

extension Span: Equatable{
    static func == (lhs: Span, rhs: Span) -> Bool {
        return  lhs.start == rhs.start && lhs.end == rhs.end
    }
}

extension Span {
    static let sample = Self(start: DateTime.sample, end: DateTime.sample)
}
