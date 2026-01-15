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
