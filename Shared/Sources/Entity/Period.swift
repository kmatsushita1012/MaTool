//
//  Period.swift
//  matool-shared
//
//  Created by 松下和也 on 2025/12/05.
//

import Foundation
import SQLiteData

// MARK: - Period
@Table public struct Period: Entity, Identifiable {
    public let id: String
    public let festivalId: Festival.ID
    @Column(as: SimpleDate.ISODateRepresentation.self)
    public let date: SimpleDate
    public var title: String
    @Column(as: SimpleTime.JSONRepresentation.self)
    public var start: SimpleTime
    @Column(as: SimpleTime.JSONRepresentation.self)
    public var end: SimpleTime
    
    public init(
        id: String = UUID().uuidString,
        festivalId: Festival.ID = "",
        title: String = "",
        date: SimpleDate,
        start: SimpleTime = .now,
        end: SimpleTime = .now
    ) {
        self.id = id
        self.festivalId = festivalId
        self.date = date
        self.title = title
        self.start = start
        self.end = end
    }
}

extension Period: Comparable {
    public static func < (lhs: Period, rhs: Period) -> Bool {
        return Date.combine(date: lhs.date, time: lhs.start) < Date.combine(date: rhs.date, time: rhs.start)
    }
}

public extension Period {
    func contains(_ datetime: Date) -> Bool {
        let startDateTime = Date.combine(date: date, time: start)
        let endDateTime = Date.combine(date: date, time: end)
        return startDateTime <= datetime && datetime <= endDateTime
    }
}

public extension Period {
    func before(_ datetime: Date) -> Bool {
        let startDateTime = Date.combine(date: date, time: start)
        return datetime <= startDateTime
    }
}
