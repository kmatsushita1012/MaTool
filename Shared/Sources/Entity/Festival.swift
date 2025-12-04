//
//  Festival.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import Foundation

public struct Festival: Codable {
    public let id: String
    public var name: String
    public var subname: String
    @NullEncodable public var description: String?
    public var prefecture: String
    public var city: String
    public var base: Coordinate
    public var periods: [Period]
    public var checkpoints: [Checkpoint]
    @NullEncodable public var imagePath: String?

    public init(
        id: String,
        name: String,
        subname: String,
        description: String? = nil,
        prefecture: String,
        city: String,
        base: Coordinate,
        periods: [Period] = [],
        checkpoints: [Checkpoint] = [],
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.subname = subname
        self.description = description
        self.prefecture = prefecture
        self.city = city
        self.base = base
        self.periods = periods
        self.checkpoints = checkpoints
        self.imagePath = imagePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id         = try container.decode(String.self, forKey: .id)
        self.name       = try container.decode(String.self, forKey: .name)
        self.subname    = try container.decode(String.self, forKey: .subname)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.prefecture = try container.decode(String.self, forKey: .prefecture)
        self.city       = try container.decode(String.self, forKey: .city)
        self.base       = try container.decode(Coordinate.self, forKey: .base)
        let legacy = try? decoder.container(keyedBy: LegacyKeys.self)
        self.checkpoints =
            try container.decodeIfPresent([Checkpoint].self, forKey: .checkpoints)
            ?? (try legacy?.decodeIfPresent([Checkpoint].self, forKey: .milestones))
            ?? []
        self.periods = try container.decodeIfPresent([Period].self, forKey: .periods)
        ?? (try legacy?.decodeIfPresent([Legacy.Span].self, forKey: .spans))?.map{ $0.toPeriod() }
        ?? []

        self.imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case subname
        case description
        case prefecture
        case city
        case base
        case periods
        case checkpoints
        case imagePath
    }

    private enum LegacyKeys: String, CodingKey {
        case milestones
        case spans
    }
}

extension Festival: Identifiable {}

// MARK: - Period
public struct Period: Entity {
    public let id: String
    public var date: SimpleDate
    public var title: String
    public var start: SimpleTime
    public var end: SimpleTime
    
    public init(id: String, title: String = "", date: SimpleDate, start: SimpleTime, end: SimpleTime) {
        self.id = id
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

// MARK: - Checkpoint
public struct Checkpoint: Entity, Identifiable {
    public let id: String
    public var name: String = ""
    @NullEncodable public var description: String? = nil
    
    public init(id: String, name: String = "", description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}
