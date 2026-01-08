//
//  ViewState.swift
//  MaTool
//
//  Created by 松下和也 on 2025/12/29.
//

import Shared

typealias ViewState = Equatable & Identifiable

enum PointViewState: ViewState {
    
    struct Checkpoint: ViewState {
        let id: String
        var masterId: String
        var title: String
        var description: String?
        var coordinate: Coordinate
        var time: SimpleTime
    }
    
    struct Performance: ViewState {
        let id: String
        var masterId: String
        var title: String
        var description: String?
        var performer: String
        var coordinate: Coordinate
        var time: SimpleTime?
    }
    
    typealias Anchor = Point.Anchor
    typealias Waypoint = Point.Waypoint
    
    case checkpoint(Checkpoint)
    case performance(Performance)
    case anchor(Anchor)
    case waypoint(Waypoint)
    
    
    var id: String {
        switch self {
        case .checkpoint(let content):
            return content.id
        case .performance(let content):
            return content.id
        case .anchor(let content):
            return content.id
        case .waypoint(let content):
            return content.id
        }
    }
}


extension PointViewState {
    var title: String? {
        switch self {
        case .checkpoint(let checkpoint):
            checkpoint.title
        case .performance(let performance):
            performance.title
        case .anchor(let anchor):
            anchor.title
        case .waypoint(let waypoint):
            nil
        }
    }
    
    var coordinate: Coordinate {
        switch self {
        case .checkpoint(let checkpoint):
            checkpoint.coordinate
        case .performance(let performance):
            performance.coordinate
        case .anchor(let anchor):
            anchor.coordinate
        case .waypoint(let waypoint):
            waypoint.coordinate
        }
    }
    
    var time: SimpleTime? {
        switch self {
        case .checkpoint(let checkpoint):
            checkpoint.time
        case .performance(let performance):
            performance.time
        case .anchor(let anchor):
            anchor.time
        case .waypoint(let waypoint):
            nil
        }
    }
}

extension PointViewState.Checkpoint{
    init(_ transaction: Point.Checkpoint, master: Shared.Checkpoint) {
        self.init(id: transaction.id, masterId: master.id, title: master.name, description: master.description, coordinate: transaction.coordinate, time: transaction.time)
    }
}

extension PointViewState.Performance{
    init(_ transaction: Point.Performance, master: Shared.Performance) {
        self.init(id: transaction.id, masterId: master.id, title: master.name, description: master.description, performer: master.performer, coordinate: transaction.coordinate, time: transaction.time)
    }
}

extension Array where Element == PointViewState {
    static func from(_ route: Route, checkpoints: [Checkpoint], performances: [Performance]) -> Self{
        let checkpointById = Dictionary(
            uniqueKeysWithValues: checkpoints.map { ($0.id, $0) }
        )
        let performanceById = Dictionary(
            uniqueKeysWithValues: performances.map { ($0.id, $0) }
        )
        return route.points.compactMap{
            switch $0 {
            case .checkpoint(let checkpoint):
                guard let master = checkpointById[checkpoint.checkpointId] else { return nil }
                return .checkpoint(.init(checkpoint, master: master))
            case .performance(let performance):
                guard let master = performanceById[performance.performanceId] else { return nil }
                return .performance(.init(performance, master: master))
            case .anchor(let anchor):
                return .anchor(anchor)
            case .waypoint(let waypoint):
                return .waypoint(waypoint)
            }
        }
    }
}

typealias FloatViewState = FloatLocationGetDTO

extension FloatViewState {
    init (_ location: FloatLocation, districtName: String) {
        self.init(districtId: location.districtId, districtName: districtName, coordinate: location.coordinate, timestamp: location.timestamp)
    }
}

enum PointType: Equatable, CaseIterable {
    case checkpoint
    case performance
    case start
    case end
    case rest
    case waypoint
    
    var title: String {
        switch self {
        case .checkpoint: return "重要地点(交差点等)"
        case .performance: return "余興"
        case .start: return "出発"
        case .end: return "到着"
        case .rest: return "休憩"
        case .waypoint: return "その他"
        }
    }
    
    //    var systemImage: String {
    //        switch self {
    //        case .checkpoint:
    //            "flag"
    //        case .performance:
    //            "figure.dance"
    //        case .start:
    //            "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
    //        case .end:
    //            "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill"
    //        case .rest:
    //
    //        case .waypoint:
    //            
    //        }
    //    }
    
    static func from(_ point: Point) -> Self {
        switch point {
        case .checkpoint(let checkpoint):
            .checkpoint
        case .performance(let performance):
            .performance
        case .anchor(let anchor):
            switch anchor.role {
            case .start:
                .start
            case .end:
                .end
            case .rest:
                .rest
            }
        case .waypoint(let waypoint):
            .waypoint
        }
    }
}
