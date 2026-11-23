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
    @Dependency(SceneControllerKey.self) var sceneController
    @Dependency(EditionControllerKey.self) var editionController
    
    func body(_ app: Application) {
        // MARK: - Edition management API
        app.get(path: "/v1/festivals/:festivalId/editions", editionController.query)
        app.post(path: "/v1/festivals/:festivalId/editions", editionController.create)
        app.get(path: "/v1/festivals/:festivalId/editions/:year", editionController.get)
        app.put(path: "/v1/festivals/:festivalId/editions/:year", editionController.put)
        app.put(path: "/v1/festivals/:festivalId/active-edition", editionController.putActive)

        // MARK: - Scene
        app.get(path: "/v2/festivals/:festivalId/launch", sceneController.launchFestival)
        // Deprecated: 新しいクライアントは /v2/festivals/:festivalId/launch を使用する。旧APIは410 Goneを返す。
        app.get(path: "/festivals/:festivalId/launch") { _, _ in .gone() }
        // MARK: - District
        app.get(path: "/festivals/:festivalId/districts", districtController.query)
        app.post(path: "/festivals/:festivalId/districts", districtController.post)
        // MARK: - Location
        app.get(path: "/festivals/:festivalId/locations", locationController.query)
        // MARK: - Period
        app.get(path: "/festivals/:festivalId/periods") { _, _ in .gone() }
        app.post(path: "/festivals/:festivalId/periods") { _, _ in .gone() }
        // MARK: - Festival
        app.get(path: "/festivals/:festivalId", festivalController.get)
        app.get(path: "/festivals", festivalController.scan)
        app.put(path: "/festivals/:festivalId", festivalController.put)
    }
}
