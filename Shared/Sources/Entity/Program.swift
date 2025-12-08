//
//  Period.swift
//  matool-shared
//
//  Created by 松下和也 on 2025/12/05.
//

import Foundation

// MARK: - Program
public struct Program: Entity {
    public let festivalId: String
    public let year: Int
    public var title: String
    public var periods: [Period]
    
    public init(festivalId: String, year: Int, title: String = "", periods: [Period]) {
        self.festivalId = festivalId
        self.year = year
        self.title = title
        self.periods = periods
    }
}

extension Program: Comparable {
    public static func < (lhs: Program, rhs: Program) -> Bool {
        return lhs.year < rhs.year
    }
}

extension Program: Identifiable {
    public var id : String {
        return "\(festivalId)_\(year)"
    }
}

// MARK: - Period
public struct Period: Entity {
    public let id: String
    public let festivalId: String
    public var date: SimpleDate
    public var title: String
    public var start: SimpleTime
    public var end: SimpleTime
    
    public init(id: String, festivalId: String = "", title: String = "", date: SimpleDate, start: SimpleTime, end: SimpleTime) {
        self.id = id
        self.festivalId = festivalId
        self.date = date
        self.title = title
        self.start = start
        self.end = end
    }
}

extension Period: Identifiable {}

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
