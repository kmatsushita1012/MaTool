//
//  AuthManager.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Shared

typealias AuthManagerFactory = @Sendable () async -> AuthManager

// MARK: - Dependencies
enum AuthManagerFactoryKey: DependencyKey{
    static let liveValue: AuthManagerFactory = {
        guard let manager = try? await CognitoAuthManager() else {
            fatalError("Cannot create CognitoAuthManager")
        }
        return manager
    }
}

// MARK: - AuthManager
protocol AuthManager: Sendable{
    func invite(username: String, email: String) async throws -> UserRole
}
