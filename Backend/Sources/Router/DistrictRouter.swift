//
//  DistrictRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import Dependencies

struct DistrictRouter: Router {
    @Dependency(DistrictControllerKey.self) var controller
    
    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId", controller.query)
        app.get(path: "/districts/:districtId/", controller.get)
        app.get(path: "/districts/:districtId/tools", controller.getTools)
        app.post(path: "/festivals/:festivalId", controller.query)
        app.put(path: "/districts/:districtId/", controller.get)
    }
}
