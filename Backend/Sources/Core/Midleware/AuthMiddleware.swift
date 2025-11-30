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
        
        guard let authHeader = request.headers["Authorization"], authHeader.starts(with: "Bearer ") else {
            request.user = .guest
            return try await next(request)
        }

        let token = String(authHeader.dropFirst("Bearer ".count))
        guard let result = try? await authManagerFactory().get(accessToken: token) else {
            return Response(statusCode: 500, headers: [:], body: "Internal Server Error")
        }
        print("Auth User: \(result) ID: \(String(describing: result.id))")
        request.user = result
        
        return try await next(request)
    }
}
