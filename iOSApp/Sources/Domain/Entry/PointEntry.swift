//
//  PointEntry.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/18.
//

import Shared
import SQLiteData

@Selection
struct PointEntry: Entity {
    let point: Point
    let checkpoint: Checkpoint?
    let performance: Performance?
    var anchor: Anchor? { point.anchor }
}

extension PointEntry: Identifiable {
    var id: Point.ID { point.id }
    
    var coordinate: Coordinate { point.coordinate }
    var time: SimpleTime? { point.time }
    
    var title: String? {
        checkpoint?.name ?? performance?.name ?? anchor?.text ?? nil
    }
    
    init(_ point: Point){
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

extension FetchAll where Element == PointEntry {
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

