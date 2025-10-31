//
//  Point.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/09.
//

import Foundation

struct Point: Codable, Identifiable, Equatable, Hashable{
    let id: String
    var coordinate: Coordinate
    @NullEncodable var title: String? = nil
    @NullEncodable var description: String? = nil
    @NullEncodable var time: SimpleTime? = nil
    var isPassed: Bool = false
    var shouldExport: Bool = false
}

extension Point {
    static let sample = Self(id: UUID().uuidString, coordinate: Coordinate.sample)
}


enum PointFilter: Equatable {
    case none
    case pub
    case export
    
    func apply(to route: Route) -> [Point] {
        return apply(to: route, visibility: route.visibility)
    }

    func apply(to route: Route, visibility: Visibility = .all) -> [Point] {
        switch self {
        case .none:
            return route.points
        case .pub:
            var newPoints:[Point] = []
            if let firstPoint = route.points.first,
               firstPoint.title == nil {
                let tempFirst = Point(
                    id: firstPoint.id,
                    coordinate: firstPoint.coordinate,
                    title: "出発",
                    time: visibility.isTimeHidden ? nil : route.start,
                    shouldExport: true
                )
                newPoints.append(tempFirst)
            }
            newPoints.append(
                contentsOf: route.points.compactMap{
                    if $0.title == nil {
                        return nil
                    }
                    var newPoint = $0
                    if visibility.isTimeHidden{
                        newPoint.time = nil
                    }
                    return newPoint
                }
            )
            if route.points.count >= 2,
               let lastPoint = route.points.last,
               lastPoint.title == nil {
                let tempLast = Point(
                    id: lastPoint.id,
                    coordinate: lastPoint.coordinate,
                    title: "到着",
                    time: visibility.isTimeHidden ? nil : route.goal,
                    shouldExport: true
                )
                newPoints.append(tempLast)
            }
            return newPoints
        case .export:
            let points = route.points
            var newPoints:[Point] = []
            if let firstPoint = points.first,
               !firstPoint.shouldExport {
                let tempFirst = Point(id: firstPoint.id, coordinate: firstPoint.coordinate, title: "出発", time: route.start, shouldExport: true)
                newPoints.append(tempFirst)
            }
            newPoints.append(contentsOf: points.filter{ $0.shouldExport })
            if points.count >= 2,
               let lastPoint = points.last,
               !lastPoint.shouldExport {
                let tempLast = Point(id: lastPoint.id, coordinate: lastPoint.coordinate, title: "到着", time: route.goal, shouldExport: true)
                newPoints.append(tempLast)
            }
            return newPoints
        }
    }
}
