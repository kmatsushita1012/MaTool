//
//  DistrictRouter.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Dependencies

struct UserRouter: Router {
    @Dependency(\.userController) var controller
    
    func body (_ app: Application) -> Void{
        app.get(path: "/name/:name", controller.get)
    }
}
