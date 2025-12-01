//
//  Response+.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

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
}

extension Application.Response {
    static func error(_ error: Swift.Error) -> Self {
        if let apiError = error as? Error {
            let body: [String: String] = [
                "message": apiError.message,
                "localizedDescription": apiError.localizedDescription
            ]
            
            return Self(
                statusCode: apiError.statusCode,
                headers: ["Content-Type": "application/json"],
                body: (try? body.toString()) ?? "{}"
            )
        } else {
            let body: [String: String] = [
                "message": "Internal Server Error",
                "localizedDescription": "\(error)"
            ]
            
            return Self(
                statusCode: 500,
                headers: ["Content-Type": "application/json"],
                body: (try? body.toString()) ?? "{}"
            )
        }
    }
}
