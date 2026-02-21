//
//  Response+.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Shared
import Foundation

extension Application.Response {
    static func success<T: Encodable>(_ body: T) throws -> Self {
        guard let json = try? body.toString() else {
            throw Error.encodingError("エンコードに失敗しました。")
        }
        return .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: json
        )
    }
    
    static func success() throws -> Self {
        return .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{}"
        )
    }
}

extension Application.Response {
    static func error(_ error: Swift.Error) -> Self {
        if let apiError = error as? Error {
            let body = apiError.response
            
            return Self(
                statusCode: apiError.statusCode,
                headers: ["Content-Type": "application/json"],
                body: (try? body.toString()) ?? "{}"
            )
        } else {
            let body = ErrorResponse(message: "Internal Server Error", localizedDescription: "予期しないエラーが発生しました。")
            
            return Self(
                statusCode: 500,
                headers: ["Content-Type": "application/json"],
                body: (try? body.toString()) ?? "{}"
            )
        }
    }
}
