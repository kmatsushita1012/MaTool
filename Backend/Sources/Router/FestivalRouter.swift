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
    @Dependency(SceneControllerKey.self) var sceneController
    
    func body(_ app: Application) {
        // MARK: - Scene
        app.get(path: "/festivals/:festivalId/launch", sceneController.launchFestival)
        // MARK: - District
        app.get(path: "/festivals/:festivalId/districts", districtController.query)
        app.post(path: "/festivals/:festivalId/districts", districtController.post)
        // MARK: - Location
        app.get(path: "/festivals/:festivalId/locations", locationController.query)
        // MARK: - Period
        app.get(path: "/festivals/:festivalId/periods/:periodId", periodController.get)
        app.delete(path: "/festivals/:festivalId/periods/:periodId", periodController.delete)
        app.get(path: "/festivals/:festivalId/periods", periodController.query)
        app.post(path: "/festivals/:festivalId/periods", periodController.post)
        app.put(path: "/festivals/:festivalId/periods", periodController.put)
        // MARK: - Festival
        app.get(path: "/festivals/:festivalId", festivalController.get)
        app.get(path: "/festivals", festivalController.scan)
        app.put(path: "/festivals", festivalController.put)
    }
}
