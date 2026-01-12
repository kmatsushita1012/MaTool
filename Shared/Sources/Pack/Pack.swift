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

public struct DistrictPack: Pack {
    public let district: District
    public let performances: [Performance]
    
    public init(district: District, performances: [Performance]){
        self.district = district
        self.performances = performances
    }
}

public struct DistrictCreateForm: Pack {
    public let name: String
    public let email: String
    
    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

public struct RouteDetailPack: Pack {
    public let route: Route
    public let points: [Point]
    
    public init(route: Route, points: [Point]) {
        self.route = route
        self.points = points
    }
}

