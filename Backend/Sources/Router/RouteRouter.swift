//
//  RouteRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/30.
//

import Dependencies

struct RouteRouter: Router {
    
    @Dependency(RouteControllerKey.self) var routeController
    
    func body(_ app: Application) {
        app.put(path: "/routes/ids", routeController.getIds)
        app.get(path: "/routes/:routeId", routeController.get)
        app.put(path: "/routes/:routeId", routeController.put)
        app.delete(path: "/routes/:routeId", routeController.delete)
        app.get(path: "/routes", routeController.query)
        app.put(path: "/routes", routeController.post)
    }
}
