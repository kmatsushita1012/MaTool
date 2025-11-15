//
//  Route.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

// MARK: - Route
public struct Route: Entity {
    public let id: String
    public let districtId: String
    public var date:SimpleDate = .today
    public var title: String = ""
    public var visibility: Visibility = .all
    @NullEncodable public var description: String?
    public var points: [Point] = []
    public var start: SimpleTime
    public var goal: SimpleTime
    
    public init(
        id: String,
        districtId: String,
        date: SimpleDate = .today,
        title: String = "",
        visibility: Visibility = .all,
        description: String? = nil,
        points: [Point] = [],
        start: SimpleTime,
        goal: SimpleTime
    ) {
        self.id = id
        self.districtId = districtId
        self.date = date
        self.title = title
        self.visibility = visibility
        self.description = description
        self.points = points
        self.start = start
        self.goal = goal
    }
}

extension Route: Identifiable {}


// MARK: - Point
public struct Point: Entity {
    public let id: String
    public var coordinate: Coordinate
    @NullEncodable public var title: String?
    @NullEncodable public var description: String?
    @NullEncodable public var time: SimpleTime?
    public var isPassed: Bool
    public var shouldExport: Bool
    
    public init(
        id: String,
        coordinate: Coordinate,
        title: String? = nil,
        description: String? = nil,
        time: SimpleTime? = nil,
        isPassed: Bool = false,
        shouldExport: Bool = false
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.description = description
        self.time = time
        self.isPassed = isPassed
        self.shouldExport = shouldExport
    }
}

extension Point: Identifiable {}

// MARK: - Visisbility
public enum Visibility: String, Entity {
    case admin
    case route
    case all
}

extension Visibility: CaseIterable {}

extension Visibility: Identifiable{
    public var id: Self { self }
}

public extension Visibility {
    var isTimeHidden: Bool {
        switch self {
        case .admin, .route:
            return true
        case .all:
            return false
        }
    }
}
