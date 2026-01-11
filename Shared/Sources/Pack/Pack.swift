//
//  Pack.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

struct FestivalPack: Pack {
    let festival: Festival
    let checkpoints: [Checkpoint]
    let hazardSections: [HazardSection]
}


public struct RouteDetailPack: Pack {
    public let route: Route
    public let points: [Point]
    
    public init(route: Route, points: [Point]) {
        self.route = route
        self.points = points
    }
}
