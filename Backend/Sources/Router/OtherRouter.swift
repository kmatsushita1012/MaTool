//
//  OtherRouter.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/01/16.
//

import Dependencies

struct OtherRouter: Router {
    
    @Dependency(SceneControllerKey.self) var sceneController
    
    func body(_ app: Application) {
        app.get(path: "/login", sceneController.login)
    }
}
