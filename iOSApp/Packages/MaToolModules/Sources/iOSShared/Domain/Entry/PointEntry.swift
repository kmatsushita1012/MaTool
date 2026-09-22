//
//  PointEntry.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import Shared
import SQLiteData

@Selection
public struct PointEntry: Entity {
    public let point: Point
    public let checkpoint: Checkpoint?
    public let performance: Performance?
    public var anchor: Anchor? { point.anchor }
}

extension PointEntry: Identifiable {
    public var id: Point.ID { point.id }
    
    public var coordinate: Coordinate { point.coordinate }
    public var time: SimpleTime? { point.time }
    
    public var title: String? {
        checkpoint?.name ?? performance?.name ?? anchor?.text ?? nil
    }
    
    public init(_ point: Point){
        self.point = point
        if let checkpointId = point.checkpointId {
            self.checkpoint = FetchOne(Checkpoint.find(checkpointId)).wrappedValue
        } else {
            self.checkpoint = nil
        }
        if let performanceId = point.performanceId {
            self.performance = FetchOne(Performance.find(performanceId)).wrappedValue
        } else {
            self.performance = nil
        }
    }
}

public extension FetchAll where Element == PointEntry {
    init(routeId: Route.ID?){
        self.init(
            Point
                .where{ $0.routeId.eq(routeId) }
                .order(by: \.index)
                .leftJoin(Checkpoint.all) { $0.checkpointId.eq($1.id) }
                .leftJoin(Performance.all) { $0.performanceId.eq($2.id) }
                .select{
                    Element.Columns(point: $0, checkpoint: $1, performance: $2)
                }
        )
    }
}
