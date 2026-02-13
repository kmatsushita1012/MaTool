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
        app.get(path: "/routes/:routeId", routeController.get)
        app.put(path: "/routes/:routeId", routeController.put)
        app.delete(path: "/routes/:routeId", routeController.delete)
        app.put(path: "/periods/:periodId", periodController.put)
        app.delete(path: "/periods/:periodId", periodController.delete)
    }
}
