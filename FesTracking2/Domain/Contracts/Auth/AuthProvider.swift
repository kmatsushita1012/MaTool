//
//  AuthProvider.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import AWSMobileClient
import Dependencies

struct AuthProvider {
    var initialize: () async -> Result<Empty, AuthError>
    var signIn: (_ username: String, _ password: String) async -> SignInResponse
    var confirmSignIn: (_ newPassword: String) async -> Result<Empty, AuthError>
    var getUserRole: () async -> Result<UserRole, AuthError>
    var getTokens: () async -> Result<Tokens, AuthError>
    var signOut: () async -> Result<Empty, AuthError>
}

extension DependencyValues {
  var authProvider: AuthProvider {
    get { self[AuthProvider.self] }
    set { self[AuthProvider.self] = newValue }
  }
}
