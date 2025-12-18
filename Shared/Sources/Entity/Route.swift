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
    public let periodId: String
    public var visibility: Visibility = .all
    @NullEncodable public var description: String?
    public var points: [Point] = []
    
    public init(
        id: String,
        districtId: String,
        periodId: String,
        visibility: Visibility = .all,
        description: String? = nil,
        points: [Point] = [],
    ) {
        self.id = id
        self.districtId = districtId
        self.periodId = periodId
        self.visibility = visibility
        self.description = description
        self.points = points
    }
}

extension Route: Identifiable {}


// MARK: - Point
public enum Point: Entity{
    case checkpoint(Checkpoint)
    case performance(Performance)
    case anchor(Anchor)
    case waypoint(Waypoint)
    
    protocol Content: Entity {
        var id: String { get }
        var coordinate: Coordinate { get set }
    }
    
    public struct Checkpoint: Content {
        public let id: String
        public var coordinate: Coordinate
        public var time: SimpleTime
        public var checkpointId: String
    }
    
    public struct Performance: Content {
        public let id: String
        public var coordinate: Coordinate
        @NullEncodable public var time: SimpleTime?
        public var performanceId: String
    }
    
    public struct Anchor: Content {
        public let id: String
        public var coordinate: Coordinate
        public var time: SimpleTime
        public var role: Role
        
        public enum Role: Entity {
            case start
            case end
            case rest
        }
    }
    
    public struct Waypoint: Content {
        public let id: String
        public var coordinate: Coordinate
    }
}

extension Point: Identifiable {
    public var id: String {
        switch self {
        case .checkpoint(let checkpoint):
            return checkpoint.id
        case .performance(let performance):
            return performance.id
        case .anchor(let anchor):
            return anchor.id
        case .waypoint(let waypoint):
            return waypoint.id
        }
    }
}

public extension Point {
    var coordinate: Coordinate {
        switch self {
        case .checkpoint(let checkpoint):
            return checkpoint.coordinate
        case .performance(let performance):
            return performance.coordinate
        case .anchor(let anchor):
            return anchor.coordinate
        case .waypoint(let waypoint):
            return waypoint.coordinate
        }
    }
    
    var time: SimpleTime? {
        switch self {
        case .checkpoint(let checkpoint):
            return checkpoint.time
        case .performance(let performance):
            return performance.time
        case .anchor(let anchor):
            return anchor.time
        case .waypoint(let waypoint):
            return nil
        }
    }
}

public extension Point.Anchor.Role {
    var title: String {
        switch self {
        case .start:
            return "出発"
        case .end:
            return "到着"
        case .rest:
            return "休憩"
        }
    }
}

public extension Point.Anchor {
    var title: String {
        role.title
    }
}

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
