//
//  Route.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import SQLiteData
import Foundation

// MARK: - Route
@Table public struct Route: Entity, Identifiable {
    public let id: String
    public let districtId: District.ID
    public let periodId: Period.ID
    public var visibility: Visibility = .all
    @NullEncodable public var description: String?
    
    public init(
        id: Self.ID = UUID().uuidString,
        districtId: District.ID,
        periodId: Period.ID,
        visibility: Visibility = .all,
        description: String? = nil
    ) {
        self.id = id
        self.districtId = districtId
        self.periodId = periodId
        self.visibility = visibility
        self.description = description
    }
}


// MARK: - Point
@Table public struct Point: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    @Column(as: Coordinate.JSONRepresentation.self)
    public var coordinate: Coordinate
    @Column(as: SimpleTime?.JSONRepresentation.self)
    @NullEncodable public var time: SimpleTime?
    // マスターデータID　いずれか1つがnon-null 全てnullなら捨てピン
    public var checkpointId: Checkpoint.ID?
    public var performanceId: Performance.ID?
    public var anchor: Anchor?
    public var index: Int
    public var isBoundary: Bool
    
    public init(
        id: Self.ID = UUID().uuidString,
        routeId: Route.ID,
        coordinate: Coordinate,
        time: SimpleTime? = nil,
        checkpointId: Checkpoint.ID? = nil,
        performanceId: Performance.ID? = nil,
        anchor: Anchor? = nil,
        index: Int = 0,
        isBoundary: Bool = false
    ) {
        self.id = id
        self.routeId = routeId
        self.coordinate = coordinate
        self.time = time
        self.checkpointId = checkpointId
        self.performanceId = performanceId
        self.anchor = anchor
        self.index = index
        self.isBoundary = isBoundary
    }
}

// MARK: - RoutePassage
@Table public struct RoutePassage: Entity, Identifiable {
    public let id: String
    public let routeId: Route.ID
    public let districtId: District.ID
    public let order: Int
    
    public init(
        id: Self.ID = UUID().uuidString,
        routeId: Route.ID,
        districtId: District.ID,
        order: Int = 0
    ) {
        self.id = id
        self.routeId = routeId
        self.districtId = districtId
        self.order = order
    }
}

// MARK: - Anchor
public enum Anchor: String, Entity, QueryBindable {
    case start
    case end
    case rest
}

// MARK: - Visisbility
public enum Visibility: String, Entity, QueryBindable {
    case admin
    case route
    case all
}

extension Visibility: CaseIterable {}

extension Visibility: Identifiable{
    public var id: Self { self }
}
