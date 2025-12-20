//
//  PeriodRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Foundation
import Shared
import Dependencies

struct PeriodRouter: Router {
    @Dependency(PeriodControllerKey.self) var controller


    func body(_ app: Application) {
        // POST /periods
        app.post(path: "/periods", controller.post)
        // PUT /periods/{id}
        app.put(path: "/periods/:id", controller.put)
        // DELETE /periods/{id}
        app.delete(path: "/periods/:id", controller.delete)
        // GET /periods/{id}
        app.get(path: "/periods/:id", controller.get)
        // GET /periods?festivalId=String&year=Int&all=Bool
        app.get(path: "/periods",controller.query)
        
    }
}

