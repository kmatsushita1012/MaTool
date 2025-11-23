//
//  Contracts.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Dependencies
import AWSLambdaRuntime
import AWSLambdaEvents

// MARK: - Router
protocol Router: Sendable{
    func body(_ app: Application) -> Void
}

// MARK: - Controller
protocol Controller: Sendable, DependencyKey {}

// MARK: - Usecase
protocol Usecase: Sendable {}

// MARK: - Repository
protocol Repository: Sendable, DependencyKey  {}

protocol MiddlewareComponent: Router {
    var path: String { get }
    var body: Middleware { get }
}

extension MiddlewareComponent {
    var path: String {
        "/"
    }
    
    func body(_ app: Application) {
        app.use(path: path, body)
    }
}

typealias Request = Application.Request
typealias Response = Application.Response
typealias Handler = Application.Handler
typealias Middleware = Application.Middleware
