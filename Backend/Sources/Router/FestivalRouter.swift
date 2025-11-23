//
//  FestivalRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Dependencies

struct FestivalRouter: Router {
    
    @Dependency(FestivalControllerKey.self) var controller
    
    func body(_ app: Application) {
        app.get(path: "/festivals/:festivalId", controller.get)
        app.get(path: "/festivals", controller.scan)
        app.put(path: "/festivals/:festivalId", controller.scan)
    }
}
