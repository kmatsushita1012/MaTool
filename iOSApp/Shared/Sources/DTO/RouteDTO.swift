//
//  RouteDTO.swift
//  MaTool
//
//  Created by 松下和也 on 2025/10/31.
//


public struct RouteItem: DTO {
    public let id: String
    public let districtId: String
    public let date:SimpleDate
    public let title: String
    public let start: SimpleTime
}

extension RouteItem: Comparable {
    public static func < (lhs: RouteItem, rhs: RouteItem) -> Bool {
        if(lhs.date != rhs.date){
            return lhs.date < rhs.date
        }else{
            return lhs.start < rhs.start
        }
    }
}

extension RouteItem: Identifiable {}

public extension RouteItem{
    init(from route: Route) {
        self.id = route.id
        self.districtId = route.districtId
        self.date = route.date
        self.title = route.title
        self.start = route.start
    }
}

public struct CurrentResponse: DTO {
    public let districtId: String
    public let districtName: String
    public let routes: [RouteItem]?
    public let current: Route?
    public let location: FloatLocationGetDTO?
}
