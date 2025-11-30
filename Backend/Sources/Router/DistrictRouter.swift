//
//  DistrictRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import Dependencies

struct DistrictRouter: Router {
    @Dependency(DistrictControllerKey.self) var districtController
    @Dependency(RouteControllerKey.self) var routeController
    
    func body(_ app: Application) {
        app.get(path: "/districts/:districtId/routes/current", routeController.getCurrent)
        app.get(path: "/districts/:districtId/routes", routeController.query)
        app.post(path: "/districts/:districtId/routes", routeController.post)
        app.get(path: "/districts/:districtId/tools", districtController.getTools)
        app.get(path: "/districts/:districtId", districtController.get)
        app.put(path: "/districts/:districtId", districtController.put)
    }
}
