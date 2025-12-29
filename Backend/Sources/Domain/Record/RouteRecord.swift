//
//  RouteRecord.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Shared

struct RouteRecord: Entity {
    let id: String
    let districtId: String
    let year: Int
    let periodId: String
    let item: Route
    
    init(item: Route, year: Int) {
        self.id = item.id
        self.districtId = item.districtId
        self.year = year
        self.periodId = item.periodId
        self.item = item
    }
}
