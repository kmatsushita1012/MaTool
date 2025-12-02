//
//  Application+Test.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

@testable import Backend

extension Application.Request {
    static func make(
        method: Application.Method,
        path: String,
        headers: [String: String] = [:],
        parameters: [String: String] = [:],
        body: String? = nil
    ) -> Self {
        .init(method: method, path: path, headers: headers, parameters: parameters, body: body)
    }
}

