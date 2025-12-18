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
    @Dependency(LocationControllerKey.self) var locationController
    @Dependency(ProgramControllerKey.self) var programController
    
    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId/districts", districtController.query)
        app.get(path: "/festivals/:festivalId/locations", locationController.query)
        app.get(path: "/festivals/:festivalId/programs/latest", programController.getLatest)
        app.get(path: "/festivals/:festivalId/programs/:year", programController.get)
        app.put(path: "/festivals/:festivalId/programs/:year", programController.put)
        app.delete(path: "/festivals/:festivalId/programs/:year", programController.delete)
        app.get(path: "/festivals/:festivalId/programs", programController.query)
        app.post(path: "/festivals/:festivalId/programs", programController.post)
        app.get(path: "/festivals/:festivalId", festivalController.get)
        app.post(path: "/festivals/:festivalId", districtController.post)
        app.get(path: "/festivals", festivalController.scan)
        app.put(path: "/festivals", festivalController.put)
    }
}
