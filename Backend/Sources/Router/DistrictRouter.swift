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
    @Dependency(LocationControllerKey.self) var locationController
    
    func body(_ app: Application) {
        app.get(path: "/districts/:districtId/tools", districtController.getTools)
        app.get(path: "/districts/:districtId/locations", locationController.get)
        app.put(path: "/districts/:districtId/locations", locationController.put)
        app.delete(path: "/districts/:districtId/locations", locationController.delete)
        app.get(path: "/districts/:districtId", districtController.get)
        app.put(path: "/districts/:districtId", districtController.put)
    }
}
