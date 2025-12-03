//
//  Others.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/24.
//

public struct InfoItem: Entity {
    public let title: String
    public let description: String?
}

public struct Information: Entity, Identifiable{
    public let id: String
    public var name: String = ""
    @NullEncodable public var description: String? = nil
    
    public init(id: String, name: String = "", description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

struct Segment: Codable{
    let id: String
    let start: Coordinate
    let end: Coordinate
    var coordinates: [Coordinate]
    let isPassed: Bool
    init(id: String,start: Coordinate, end: Coordinate, coordinates: [Coordinate]? = nil, isPassed: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.coordinates = coordinates ?? [start, end]
        self.isPassed = isPassed
    }
}

extension Segment: Equatable {
}

extension Segment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct Pair<Element: Equatable>: Equatable {
    public let first: Element
    public let second: Element
}

public struct Empty: Equatable, Codable {
    public init(){}
}
