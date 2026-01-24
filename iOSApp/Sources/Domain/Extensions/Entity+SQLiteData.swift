//
//  Entity+SQLiteData.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/19.
//

import SQLiteData
import Shared

extension FetchAll where Element == Point {
    init(routeId: Route.ID){
        self.init(Point.where{ $0.routeId == routeId })
    }
}
