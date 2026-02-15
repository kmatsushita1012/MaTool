//
//  AuthProvider.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies
import Shared
import Amplify
import AWSCognitoAuthPlugin

// MARK: - Dependencies
extension DependencyValues {
  var authProvider: AuthProvider {
    get { self[AuthProvider.self] }
    set { self[AuthProvider.self] = newValue }
  }
}

// MARK: - AuthProvider(Protocol)
struct AuthProvider: Sendable {
    nonisolated var initialize: @Sendable () throws -> Void
    var signIn: @Sendable (_ username: String, _ password: String) async throws -> SignInResponse
    var confirmSignIn: @Sendable (_ newPassword: String) async throws -> Void
    var getUserRole: @Sendable () async throws -> UserRole
    var getTokens: @Sendable () async throws -> String
    var signOut: @Sendable () async throws -> Void
    var changePassword: @Sendable (_ current: String, _ new: String) async throws -> Void
    var resetPassword: @Sendable (_ username: String) async throws -> Void
    var confirmResetPassword: @Sendable (_ username: String,_ newPassword: String, _ code: String) async throws -> Void
    var updateEmail: @Sendable (_ newEmail: String) async throws -> UpdateEmailState
    var confirmUpdateEmail: @Sendable (_ code: String) async throws -> Void
}

// MARK: - AuthProvider(AWS)
extension AuthProvider: DependencyKey {
    static let liveValue = {
        let timeout: Int = 5
        
        return Self(
            initialize: {
                do {
                    try Amplify.add(plugin: AWSCognitoAuthPlugin())
                    try Amplify.configure()
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "signIn")
                }
            },
            signIn: { username, password in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.signIn(username: username, password: password)
                    }
                    if result.isSignedIn {
                        return .success
                    } else if case .confirmSignInWithNewPassword = result.nextStep {
                        return .newPasswordRequired
                    } else {
                        throw AuthError.unknown("予期しないエラーです \(result.nextStep)")
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "signIn")
                }
            },
            
            confirmSignIn: { newPassword in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.confirmSignIn(challengeResponse: newPassword)
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "confirmSignIn")
                }
            },
            
            getUserRole: {
                do {
                    let (attributes, user) = try await withTimeout(seconds: timeout) {
                        async let attributes = Amplify.Auth.fetchUserAttributes()
                        async let user = Amplify.Auth.getCurrentUser()
                        return try await (attributes, user)
                    }
                    
                    if let role = attributes.first(where: { $0.key.rawValue == "custom:role" })?.value {
                        switch role {
                        case "region": return .headquarter(user.username)
                        case "district": return .district(user.username)
                        default: return .guest
                        }
                    }
                    return .guest
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "getUserRole")
                }
            },
            
            getTokens: {
                do {
                    let session = try await Amplify.Auth.fetchAuthSession() as? AWSAuthCognitoSession
                    let result = session?.getCognitoTokens()
                    switch result {
                    case .success(let tokens):
                        return tokens.accessToken
                    case .failure(let error):
                        throw error
                    case .none:
                        throw AuthError.unknown("アクセストークンの取得に失敗しました。")
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "getTokens")
                }
            },
            signOut: {
                do {
                    let _ = try await withTimeout(seconds: timeout) {
                        await Amplify.Auth.signOut()
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "signOut")
                }
            },
            
            changePassword: { current, new in
                do {
                    try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.update(oldPassword: current, to: new)
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "changePassword")
                }
            },
            
            resetPassword: { username in
                do {
                    _ = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.resetPassword(for: username)
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "resetPassword")
                }
            },
            
            confirmResetPassword: { username, newPassword, code in
                do {
                    try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.confirmResetPassword(
                            for: username,
                            with: newPassword,
                            confirmationCode: code
                        )
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "confirmResetPassword")
                }
            },
            
            updateEmail: { newEmail in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.update(userAttribute: .init(.email, value: newEmail))
                    }
                    switch result.nextStep {
                    case .done:
                        return .completed
                    case .confirmAttributeWithCode(_, _):
                        //TODO: destination
                        return .verificationRequired(destination: newEmail)
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "updateEmail")
                }
            },
            confirmUpdateEmail: { code in
                do {
                    try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.confirm(userAttribute: .email, confirmationCode: code)
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "confirmUpdateEmail")
                }
            }
        )
    }()
}

private extension AuthProvider {
    static func rethrowAsAuthErrorIfNeeded(_ error: Error, operation: String) throws -> Never {
        if let parsed = AuthError.parse(error, operation: operation) {
            throw parsed
        }
        throw error
    }
}
