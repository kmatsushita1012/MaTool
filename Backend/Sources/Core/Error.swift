//
//  Error.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

enum APIError: Error {
    case notFound(message: String)
    case badRequest(message: String)
    case internalServerError(message: String)
    case unauthorized(message: String)
    case conflict(message: String)

    static func notFound(_ message: String = "Not Found") -> APIError {
        .notFound(message: message)
    }

    static func badRequest(_ message: String = "Bad Request") -> APIError {
        .badRequest(message: message)
    }

    static func internalServerError(_ message: String = "Internal Server Error") -> APIError {
        .internalServerError(message: message)
    }

    static func unauthorized(_ message: String = "Unauthorized") -> APIError {
        .unauthorized(message: message)
    }
    
    static func conflict(_ message: String = "Conflict") -> APIError {
        .conflict(message: message)
    }
}
