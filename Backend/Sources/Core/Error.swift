//
//  Error.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Foundation

enum APIError: Error {
    case notFound(String?)
    case badRequest(String?)
    case internalServerError(String?)
    case unauthorized(String?)
    case conflict(String?)
    case encodingError(String?)
    case decodingError(String?)
}
extension APIError{
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

extension APIError {
    static func notFound(localizedDescription: String? = nil) -> APIError {
        .notFound(localizedDescription)
    }

    static func badRequest(localizedDescription: String? = nil) -> APIError {
        .badRequest(localizedDescription)
    }

    static func internalServerError(localizedDescription: String? = nil) -> APIError {
        .internalServerError(localizedDescription)
    }

    static func unauthorized(localizedDescription: String? = nil) -> APIError {
        .unauthorized(localizedDescription)
    }
    
    static func conflict(localizedDescription: String? = nil) -> APIError {
        .conflict(localizedDescription)
    }
    
    static func encodingError(localizedDescription: String? = nil) -> APIError {
        .encodingError(localizedDescription)
    }
    
    static func decodingError(localizedDescription: String? = nil) -> APIError {
        .decodingError(localizedDescription)
    }
}

extension Application.Response {
    init(error: Error) {
        if let apiError = error as? APIError {
            let dict: [String: String] = [
                "message": apiError.message,
                "localizedDescription": apiError.localizedDescription
            ]
            
            let bodyData = try? JSONEncoder().encode(dict)
            
            self.statusCode = apiError.statusCode
            self.headers = ["Content-Type": "application/json"]
            self.body = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        } else {
            let dict: [String: String] = [
                "message": "Internal Server Error",
                "localizedDescription": ""
            ]
            
            let bodyData = try? JSONEncoder().encode(dict)
            
            self.statusCode = 500
            self.headers = ["Content-Type": "application/json"]
            self.body = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        }
    }
}
