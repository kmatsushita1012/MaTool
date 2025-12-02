//
//  FestivalRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

import Dependencies

struct FestivalRouter: Router {
    @Dependency(FestivalControllerKey.self) var festivalController
    @Dependency(DistrictControllerKey.self) var districtController
    
    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId/districts", districtController.query)
        app.get(path: "/festivals/:festivalId", festivalController.get)
        app.post(path: "/festivals/:festivalId", districtController.post)
        app.get(path: "/festivals", festivalController.scan)
        app.put(path: "/festivals", festivalController.put)
    }
}
