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
    @Dependency(PeriodControllerKey.self) var periodController
    
    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId/districts", districtController.query)
        app.get(path: "/festivals/:festivalId/locations", locationController.query)
        // MARK: - Period
        app.get(path: "/festivals/:festivalId/periods/:periodId", periodController.get)
        app.delete(path: "/festivals/:festivalId/periods/:periodId", periodController.delete)
        app.get(path: "/festivals/:festivalId/periods", periodController.query)
        app.post(path: "/festivals/:festivalId/periods", periodController.post)
        app.put(path: "/festivals/:festivalId/periods", periodController.put)
        
        app.get(path: "/festivals/:festivalId", festivalController.get)
        app.post(path: "/festivals/:festivalId", districtController.post)
        app.get(path: "/festivals", festivalController.scan)
        app.put(path: "/festivals", festivalController.put)
    }
}
