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
    @Dependency(SceneControllerKey.self) var sceneController
    
    func body(_ app: Application) {
        // MARK: - Scene
        app.get(path: "/districts/:districtId/launch", sceneController.launchDistrict)
        app.get(path: "/districts/:districtId/launch-festival", sceneController.launchFestival)
        // MARK: - Route
        app.get(path: "/districts/:districtId/routes", routeController.query)
        app.post(path: "/districts/:districtId/routes", routeController.post)
        // MARK: - Location
        app.get(path: "/districts/:districtId/locations", locationController.get)
        app.put(path: "/districts/:districtId/locations", locationController.put)
        app.delete(path: "/districts/:districtId/locations", locationController.delete)
        // MARK: - District
        app.get(path: "/districts/:districtId", districtController.get)
        app.put(path: "/districts/:districtId", districtController.put)
    }
}
