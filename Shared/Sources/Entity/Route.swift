//
//  Route.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/30.
//

import SQLiteData

// MARK: - Route
@Table public struct Route: Entity, Identifiable {
    public let id: String
    public let districtId: District.ID
    public let periodId: Period.ID
    public var visibility: Visibility = .all
    @NullEncodable public var description: String?
    
    public init(
        id: String,
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
    @Column(as: Coordinate.JSONRepresentation.self)
    public var coordinate: Coordinate
    @Column(as: SimpleTime?.JSONRepresentation.self)
    @NullEncodable public var time: SimpleTime?
    // マスターデータID　いずれか1つがnon-null 全てnullなら捨てピン
    public let checkpointId: Checkpoint.ID?
    public let performanceId: Performance.ID?
    public let anchor: Anchor?
    
    public init(id: String, coordinate: Coordinate, time: SimpleTime? = nil, checkpointId: Checkpoint.ID?, performanceId: Performance.ID?, anchor: Anchor?) {
        self.id = id
        self.coordinate = coordinate
        self.time = time
        self.checkpointId = checkpointId
        self.performanceId = performanceId
        self.anchor = anchor
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
