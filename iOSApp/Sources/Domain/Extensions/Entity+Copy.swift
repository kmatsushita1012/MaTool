//
//  Entity+Copy.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/19.
//

import Shared
import Foundation

extension Route {
    func copyWith(districtId: District.ID, periodId: Period.ID) -> Self{
        .init(id: UUID().uuidString, districtId: districtId, periodId: periodId, visibility: self.visibility, description: self.description)
    }
}

extension Point {
    func copyWith(routeId: Route.ID) -> Self{
        .init(
            id: UUID().uuidString,
            routeId: routeId,
            coordinate: self.coordinate,
            time: self.time,
            checkpointId: self.checkpointId,
            performanceId: self.performanceId,
            anchor: self.anchor,
            index: self.index
        )
    }
}

extension Array where Element == Point {
    func copyWith(routeId: Route.ID) -> Self {
        self.map{ $0.copyWith(routeId: routeId) }
    }
}

extension RoutePassage {
    func copyWith(routeId: Route.ID) -> Self{
        .init(routeId: routeId, districtId: self.districtId)
    }
}

extension Array where Element == RoutePassage {
    func copyWith(routeId: Route.ID) -> Self {
        self.map{ $0.copyWith(routeId: routeId) }
    }
}
