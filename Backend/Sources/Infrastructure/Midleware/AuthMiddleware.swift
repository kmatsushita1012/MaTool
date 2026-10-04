//
//  MidleWare.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/10/27.
//

import AWSCognitoIdentityProvider
import Dependencies
import Shared

// MARK: - AuthMiddleware
struct AuthMiddleware: MiddlewareComponent {
    var path: String
    
    var body: Middleware = { req, next in
        var request = req
        @Dependency(AuthManagerFactoryKey.self) var authManagerFactory
        
        guard let authHeader = request.headers["authorization"], authHeader.starts(with: "Bearer ") else {
            request.user = .guest
            return try await next(request)
        }

        let token = String(authHeader.dropFirst("Bearer ".count))
        let authManager = try await authManagerFactory()
        let result: UserRole
        do {
            result = try await authManager.get(accessToken: token)
        } catch is NotAuthorizedException {
            throw Application.Error.unauthorized("認証に失敗しました。再度サインインしてください。")
        }
        print("Auth User: \(result) ID: \(String(describing: result.id))")
        request.user = result
        
        return try await next(request)
    }
}
