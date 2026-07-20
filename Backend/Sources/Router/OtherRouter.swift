//
//  OtherRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Dependencies

struct OtherRouter: Router {
    
    @Dependency(RouteControllerKey.self) var routeController
    @Dependency(PeriodControllerKey.self) var periodController
    
    func body(_ app: Application) {
        // MARK: - Health
        app.get(path: "/health") { _, _ in
            try .success()
        }
        // MARK: - Route
        app.get(path: "/routes/:routeId", routeController.get)
        app.put(path: "/routes/:routeId", routeController.put)
        app.delete(path: "/routes/:routeId", routeController.delete)
        // MARK: - Period
        app.put(path: "/periods/:periodId", periodController.put)
        app.delete(path: "/periods/:periodId", periodController.delete)
        app.get(path: "/periods/:periodId", periodController.get)
    }
}
