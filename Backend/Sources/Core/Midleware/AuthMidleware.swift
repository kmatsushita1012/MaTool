//
//  MidleWare.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//



struct AuthMiddleware: MiddlewareComponent {
    var path: String
    
    var body: Middleware = { req, next in
        var request = req
//        if let auth = req.headers["authorization"] {
//            // ここで Cognito検証などを行う
//            if auth.contains("region") {
//                request.user = UserRole(type: .region, id: "user123")
//            } else {
//                request.user = UserRole(type: .guest, id: nil)
//            }
//        } else {
//            request.user = UserRole(type: .guest, id: nil)
//        }
        print("Authenticated as \(request.user?.type.rawValue ?? "unknown")")
        return await next(request)
    }
}
