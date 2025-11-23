//
//  Error.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Foundation

enum APIError: Error {
    case notFound(message: String?)
    case badRequest(message: String?)
    case internalServerError(message: String?)
    case unauthorized(message: String?)
    case conflict(message: String?)
    case encodingError(message: String?)
    case decodingError(message: String?)
}
extension APIError{
    var title: String{
        switch self {
        case .notFound(_):
            return "Not Fount"
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
    
    func response() -> Application.Response {
        let dict: [String: String] = [
            "title": self.title,
            "detail": self.message ?? ""
        ]
        
        let bodyData = try? JSONEncoder().encode(dict)
        let bodyString = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return Application.Response(
            statusCode: self.statusCode,
            headers: ["Content-Type": "application/json"],
            body: bodyString
        )
    }
    
    /// message を簡単に取得
    private var message: String? {
        switch self {
        case .notFound(let message),
             .badRequest(let message),
             .internalServerError(let message),
             .unauthorized(let message),
             .conflict(let message),
             .encodingError(let message),
             .decodingError(let message):
            return message
        }
    }
}

extension APIError {
    static func notFound(_ message: String? = nil) -> APIError {
        .notFound(message: message)
    }

    static func badRequest(_ message: String? = nil) -> APIError {
        .badRequest(message: message)
    }

    static func internalServerError(_ message: String? = nil) -> APIError {
        .internalServerError(message: message)
    }

    static func unauthorized(_ message: String? = nil) -> APIError {
        .unauthorized(message: message)
    }
    
    static func conflict(_ message: String? = nil) -> APIError {
        .conflict(message: message)
    }
    
    static func encodingError(_ message: String? = nil) -> APIError {
        .encodingError(message: message)
    }
    
    static func decodingError(_ message: String? = nil) -> APIError {
        .decodingError(message: message)
    }
}

extension Error {
    var response: Application.Response {
        print(self.localizedDescription)
        if let apiError = self as? APIError {
            return apiError.response
        }
        return .internalServerError("不明なエラー")
    }
}
