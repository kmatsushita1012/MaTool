//
//  Error.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Foundation


typealias Error = Application.Error

extension Error{
    var message: String{
        switch self {
        case .notFound(_):
            return "Not Found"
        case .badRequest(_):
            return "Bad Request"
        case .internalServerError(_):
            return "Internal Server Error"
        case .unauthorized(_):
            return "Unauthorized"
        case .conflict(_):
            return "Conflict"
        case .encodingError(_):
            return "Encoding Error"
        case .decodingError(_):
            return "Decoding Error"
        }
    }

    var statusCode: Int {
        switch self {
        case .notFound: return 404
        case .badRequest: return 400
        case .internalServerError: return 500
        case .unauthorized: return 401
        case .conflict: return 409
        case .encodingError, .decodingError: return 500
        }
    }
    
    /// message を簡単に取得
    var localizedDescription: String {
        switch self {
        case .notFound(let message),
             .badRequest(let message),
             .internalServerError(let message),
             .unauthorized(let message),
             .conflict(let message),
             .encodingError(let message),
             .decodingError(let message):
            return message ?? "unknown"
        }
    }
}

extension Error {
    static func notFound(localizedDescription: String? = nil) -> Error {
        .notFound(localizedDescription)
    }

    static func badRequest(localizedDescription: String? = nil) -> Error {
        .badRequest(localizedDescription)
    }

    static func internalServerError(localizedDescription: String? = nil) -> Error {
        .internalServerError(localizedDescription)
    }

    static func unauthorized(localizedDescription: String? = nil) -> Error {
        .unauthorized(localizedDescription)
    }
    
    static func conflict(localizedDescription: String? = nil) -> Error {
        .conflict(localizedDescription)
    }
    
    static func encodingError(localizedDescription: String? = nil) -> Error {
        .encodingError(localizedDescription)
    }
    
    static func decodingError(localizedDescription: String? = nil) -> Error {
        .decodingError(localizedDescription)
    }
}

