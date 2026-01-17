//
//  Pack.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

public struct FestivalPack: Pack {
    public let festival: Festival
    public let checkpoints: [Checkpoint]
    public let hazardSections: [HazardSection]
    
    public init(festival: Festival, checkpoints: [Checkpoint], hazardSections: [HazardSection]) {
        self.festival = festival
        self.checkpoints = checkpoints
        self.hazardSections = hazardSections
    }
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

// MARK: - ScenePack
// 起動時/ Default-Festival設定変更時に取得
// Default-Festival基準
public struct LaunchFestivalPack: Pack {
    public let festival: Festival
    public let districts: [District]
    public let periods: [Period] // Adminなら全期間 Publicならlatest
    public let locations: [FloatLocation]
    public let checkpoints: [Checkpoint] // Adminのみ
    public let hazardSections: [HazardSection] // Adminのみ
    
    public init(festival: Festival, districts: [District], periods: [Period], locations: [FloatLocation], checkpoints: [Checkpoint], hazardSections: [HazardSection]) {
        self.festival = festival
        self.districts = districts
        self.periods = periods
        self.locations = locations
        self.checkpoints = checkpoints
        self.hazardSections = hazardSections
    }
}

// District基準
// 起動時&Default-District設定変更時に取得
// Default-Districtが決まってない場合は取得しない
public struct LaunchDistrictPack: Pack {
    public let performances: [Performance]
    public let routes: [Route]
    public let points: [Point]
    public let currentRouteId: Route.ID?
    
    public init(performances: [Performance], routes: [Route], points: [Point], currentRouteId: Route.ID?) {
        self.performances = performances
        self.routes = routes
        self.points = points
        self.currentRouteId = currentRouteId
    }
}
