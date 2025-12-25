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
    
    public init(
        districtId: String,
        districtName: String,
        period: Period,
        route: Route
    ) {
        self.districtId = districtId
        self.districtName = districtName
        self.period = period
        self.route = route
    }
}

public struct RoutesResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let items: [Item]
    
    public struct Item: DTO {
        public let routeId: String?
        public let isVisible: Bool
        public let period: Period
        
        public init(routeId: String?, isVisible: Bool,  period: Period) {
            self.routeId = routeId
            self.isVisible = isVisible
            self.period = period
        }
    }
    
    public init(districtId: String, districtName: String, items: [Item]) {
        self.districtId = districtId
        self.districtName = districtName
        self.items = items
    }
}

public struct CurrentResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let items: [RouteItem]
    public let detail: RouteDetail?
    public let location: FloatLocation?
    public let message: String?
    
    public struct RouteItem: DTO {
        public let routeId: String?
        public let isVisible: Bool
        public let period: Period
        
        public init(routeId: String?, isVisible: Bool,  period: Period) {
            self.routeId = routeId
            self.isVisible = isVisible
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
    
    public init(districtId: String, districtName: String, items: [RouteItem], detail: RouteDetail?, location: FloatLocation?, message: String?) {
        self.districtId = districtId
        self.districtName = districtName
        self.items = items
        self.detail = detail
        self.location = location
        self.message = message
    }
}
