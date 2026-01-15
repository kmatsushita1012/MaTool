//
//  DataFetcher.swift
//  MaTool
//
//  Created by 松下和也 on 2026/01/14.
//

import Dependencies

protocol DataFetcher: Sendable {}


extension DataFetcher {
    func getToken() async throws -> String {
        @Dependency(AuthServiceKey.self) var authService
        
        guard let token = await authService.getAccessToken() else { throw APIError.unauthorized(message: "ログインセッションが切れました。もう一度ログインしてください") }
        return token
    }
}

enum Query: Sendable, Equatable {
    case all
    case year(Int)
    case latest

    var queryItems: [String: Any] {
        switch self {
        case .all:
            return [:]
        case .year(let y):
            return ["year": y]
        case .latest:
            return ["year": "latest"]
        }
    }
}
