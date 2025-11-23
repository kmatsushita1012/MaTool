//
//  MidleWare.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/10/27.
//

import AWSCognitoIdentityProvider
import Dependencies

// MARK: - AuthMiddleware
struct AuthMiddleware: MiddlewareComponent {
    var path: String
    
    var body: Middleware = { req, next in
        var request = req
        @Dependency(AuthManagerFactoryKey.self) var authManagerFactory
        
        guard let authHeader = request.headers["authorization"], authHeader.starts(with: "Bearer ") else {
            request.user = .guest
            print("Authorization doesn't exist")
            return try await next(request)
        }

        let token = String(authHeader.dropFirst("Bearer ".count))
        guard let result = try? await authManagerFactory().get(accessToken: token) else {
            throw Error.unauthorized("Authorization failed")
        }
        request.user = result
        print("Authorization exists \(result)")
        return try await next(request)
    }
}
