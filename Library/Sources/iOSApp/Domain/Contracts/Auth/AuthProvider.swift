//
//  AuthProvider.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies
import Shared

struct AuthProvider: Sendable {
    var initialize: @Sendable () -> Result<Empty, AuthError>
    var signIn: @Sendable (_ username: String, _ password: String) async -> SignInResponse
    var confirmSignIn: @Sendable (_ newPassword: String) async -> Result<Empty, AuthError>
    var getUserRole: @Sendable () async -> Result<UserRole, AuthError>
    var getTokens: @Sendable () async -> Result<String, AuthError>
    var signOut: @Sendable () async -> Result<Empty, AuthError>
    var changePassword: @Sendable (_ current: String, _ new: String) async -> Result<Empty,AuthError>
    var resetPassword: @Sendable (_ username: String) async -> Result<Empty,AuthError>
    var confirmResetPassword: @Sendable (_ username: String,_ newPassword: String, _ code: String) async -> Result<Empty,AuthError>
    var updateEmail: @Sendable (_ newEmail: String) async -> UpdateEmailResult
    var confirmUpdateEmail: @Sendable (_ code: String) async -> Result<Empty,AuthError>
}

extension DependencyValues {
  var authProvider: AuthProvider {
    get { self[AuthProvider.self] }
    set { self[AuthProvider.self] = newValue }
  }
}
