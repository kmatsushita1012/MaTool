//
//  Entity+.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/26.
//

import MapKit
import Shared

extension Point.Checkpoint {
    func title(from namesById: [String : String]) -> String? {
        return namesById[checkpointId]
    }
    
    func title(from checkpointsById: [String : Checkpoint]) -> String? {
        return checkpointsById[checkpointId]?.name
    }
    
    func title(from checkpoints: [Checkpoint]) -> String? {
        let namesById: [String: String] =  Dictionary(
            uniqueKeysWithValues: checkpoints.map { ($0.id, $0.name) }
        )
        return title(from: namesById)
    }
}

extension Point.Performance {
    func title(from namesById: [String : String]) -> String? {
        return namesById[performanceId]
    }
    
    func title(from performancesById: [String : Performance]) -> String? {
        return performancesById[performanceId]?.name
    }
    
    func title(from performances: [Performance]) -> String? {
        let namesById: [String: String] =  Dictionary(
            uniqueKeysWithValues: performances.map { ($0.id, $0.name) }
        )
        return title(from: namesById)
    }
}

extension Point.Anchor.Role{
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

extension Point.Anchor {
    var title: String {
        role.title
    }
}

extension Point{
    func title(namesById: [String: String]) -> String? {
        switch self {
        case .checkpoint(let checkpoint):
            checkpoint.title(from: namesById)
        case .performance(let performance):
            performance.title(from: namesById)
        case .anchor(let anchor):
            anchor.title
        case .waypoint:
            nil
        }
    }
}

    

extension Array where Element == Point {
    var pair: [Pair<Point>] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { Pair(first: $0, second: $1) }
    }
}

extension Pair where Element == Point {
    var polyline: PathPolyline {
        let coords = [self.first, self.second].map { $0.coordinate.toCL() }
        let polyline = PathPolyline(coordinates: coords, count: coords.count)
        return polyline
    }
}

extension RoutesResponse.Item: @retroactive Identifiable {
    public var id: String {
        period.id
    }
}
