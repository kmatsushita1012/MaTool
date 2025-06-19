//
//  AuthProvider.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import AWSMobileClient
import Dependencies

struct AuthProvider {
    var initialize: () async -> Result<String, AuthError>
    var signIn: (_ username: String, _ password: String) async -> AuthSignInResult
    var confirmSignIn: (_ newPassword: String) async -> Result<String, AuthError>
    var getUserRole: () async -> Result<UserRole, AuthError>
    var getTokens: () async -> Result<Tokens, AuthError>
    var signOut: () async -> Result<Bool, AuthError>
}

extension DependencyValues {
  var authProvider: AuthProvider {
    get { self[AuthProvider.self] }
    set { self[AuthProvider.self] = newValue }
  }
}
