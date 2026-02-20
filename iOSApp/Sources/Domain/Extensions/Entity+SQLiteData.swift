//
//  Entity+SQLiteData.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/19.
//

import SQLiteData
import Shared

extension FetchAll where Element == District {
    init(festivalId: Festival.ID){
        self.init(District.where{ $0.festivalId == festivalId }.order(by: \.order))
    }
}

extension FetchAll where Element == Point {
    init(routeId: Route.ID){
        self.init(Point.where{ $0.routeId == routeId })
    }
}

extension FetchAll where Element == RoutePassage {
    init(routeId: Route.ID){
        self.init(RoutePassage.where{ $0.routeId == routeId })
    }
}

extension FetchAll where Element == HazardSection {
    init(festivalId: Festival.ID) {
        self.init(HazardSection.where{ $0.festivalId == festivalId })
    }
}

extension FetchOne where Value == District {
    init(_ value: District){
        self.init(wrappedValue: value, District.find(value.id))
    }
}

extension FetchOne where Value == Festival {
    init(_ value: Festival){
        self.init(wrappedValue: value, Festival.find(value.id))
    }
}

extension FetchOne where Value == Period {
    init(_ value: Period){
        self.init(wrappedValue: value, Period.find(value.id))
    }
}
