//
//  RouteDTO.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/31.
//


public struct RouteResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let period: Period
    public let route: Route
    public let checkpoints: [Checkpoint]
    public let performances: [Performance]
    
    public init(
        districtId: String,
        districtName: String,
        period: Period, route: Route,
        checkpoints: [Checkpoint],
        performances: [Performance]
    ) {
        self.districtId = districtId
        self.districtName = districtName
        self.period = period
        self.route = route
        self.checkpoints = checkpoints
        self.performances = performances
    }
}

public struct RoutesResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let periods: [Item]
    
    public struct Item: DTO {
        public let exsists: Bool
        public let period: Period
        
        public init(exsists: Bool, period: Period) {
            self.exsists = exsists
            self.period = period
        }
    }
    
    public init(districtId: String, districtName: String, periods: [Item]) {
        self.districtId = districtId
        self.districtName = districtName
        self.periods = periods
    }
}

public struct CurrentResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let routes: [RouteItem]
    public let route: RouteDetail?
    public let location: FloatLocationGetDTO?
    
    public struct RouteItem: DTO {
        public let exsists: Bool
        public let period: Period
        
        public init(exsists: Bool, period: Period) {
            self.exsists = exsists
            self.period = period
        }
    }
    
    public struct RouteDetail: DTO {
        public let period: Period
        public let route: Route
        public let checkpoints: [Checkpoint]
        public let performances: [Performance]
        
        public init(period: Period, route: Route, checkpoints: [Checkpoint], performances: [Performance]) {
            self.period = period
            self.route = route
            self.checkpoints = checkpoints
            self.performances = performances
        }
    }
    
    public init(districtId: String, districtName: String, routes: [RouteItem], route: RouteDetail?, location: FloatLocationGetDTO?) {
        self.districtId = districtId
        self.districtName = districtName
        self.routes = routes
        self.route = route
        self.location = location
    }
}
