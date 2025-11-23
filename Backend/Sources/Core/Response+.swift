//
//  Response+.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/23.
//

import Foundation

extension Application.Response {
    static func success(_ body: String) -> Self{
        return .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }
}

extension Application.Response {
    static func error(_ error: Swift.Error) -> Self {
        if let apiError = error as? Error {
            let dict: [String: String] = [
                "message": apiError.message,
                "localizedDescription": apiError.localizedDescription
            ]
            
            let bodyData = try? JSONEncoder().encode(dict)
            
            return Self(
                statusCode: apiError.statusCode,
                headers: ["Content-Type": "application/json"],
                body: bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            )
        } else {
            let dict: [String: String] = [
                "message": "Internal Server Error",
                "localizedDescription": ""
            ]
            
            let bodyData = try? JSONEncoder().encode(dict)
            
            return Self(
                statusCode: 500,
                headers: ["Content-Type": "application/json"],
                body: bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            )
        }
    }
}
