//
//  AuthManager.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Shared

typealias AuthManagerFactory = @Sendable () async throws -> AuthManager

// MARK: - Dependencies
enum AuthManagerFactoryKey: DependencyKey {
    static let liveValue: AuthManagerFactory = {
        return try await CognitoAuthManager()
    }
}

// MARK: - AuthManager
protocol AuthManager: Sendable {
    func create(username: String, email: String) async throws -> UserRole
    func get(accessToken: String) async throws -> UserRole
    func get(username: String) async throws -> UserRole
}
