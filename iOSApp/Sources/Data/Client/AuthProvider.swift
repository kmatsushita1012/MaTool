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
import OSLog

private let authProviderLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MaTool", category: "AuthProvider")

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
    static let testValue = Self(
        initialize: unimplemented("AuthProvider.initialize"),
        signIn: unimplemented("AuthProvider.signIn"),
        confirmSignIn: unimplemented("AuthProvider.confirmSignIn"),
        getUserRole: unimplemented("AuthProvider.getUserRole"),
        getTokens: unimplemented("AuthProvider.getTokens"),
        signOut: unimplemented("AuthProvider.signOut"),
        changePassword: unimplemented("AuthProvider.changePassword"),
        resetPassword: unimplemented("AuthProvider.resetPassword"),
        confirmResetPassword: unimplemented("AuthProvider.confirmResetPassword"),
        updateEmail: unimplemented("AuthProvider.updateEmail"),
        confirmUpdateEmail: unimplemented("AuthProvider.confirmUpdateEmail")
    )

    static let liveValue = {
        let timeout: Int = 5
        
        return Self(
            initialize: {
                do {
                    try Amplify.add(plugin: AWSCognitoAuthPlugin())
                    try Amplify.configure()
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "initialize")
                }
            },
            signIn: { username, password in
                authProviderLogger.info("signIn: started")
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.signIn(username: username, password: password)
                    }
                    if result.isSignedIn {
                        authProviderLogger.info("signIn: completed")
                        return .success
                    } else if case .confirmSignInWithNewPassword = result.nextStep {
                        authProviderLogger.info("signIn: new password required")
                        return .newPasswordRequired
                    } else {
                        throw AppError.auth(.unknown("予期しないエラーです \(result.nextStep)"))
                    }
                } catch {
                    authProviderLogger.error("signIn: failed (\(String(reflecting: type(of: error)), privacy: .public))")
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
                authProviderLogger.info("getUserRole: started")
                do {
                    let (attributes, user) = try await withTimeout(seconds: timeout) {
                        async let attributes = Amplify.Auth.fetchUserAttributes()
                        async let user = Amplify.Auth.getCurrentUser()
                        return try await (attributes, user)
                    }
                    
                    if let role = attributes.first(where: { $0.key.rawValue == "custom:role" })?.value {
                        switch role {
                        case "region":
                            authProviderLogger.info("getUserRole: completed as headquarter")
                            return .headquarter(user.username)
                        case "district":
                            authProviderLogger.info("getUserRole: completed as district")
                            return .district(user.username)
                        default:
                            authProviderLogger.info("getUserRole: completed as guest")
                            return .guest
                        }
                    }
                    authProviderLogger.info("getUserRole: completed without role attribute")
                    return .guest
                } catch {
                    authProviderLogger.error("getUserRole: failed (\(String(reflecting: type(of: error)), privacy: .public))")
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "getUserRole")
                }
            },
            
            getTokens: {
                do {
                    return try await withTimeout(seconds: timeout) {
                        guard let session = try await Amplify.Auth.fetchAuthSession() as? AWSAuthCognitoSession else {
                            throw AppError.auth(.unknown("予期せぬエラーが発生しました"))
                        }
                        guard session.isSignedIn else {
                            throw AppError.auth(.unauthorized("ログインしていません。"))
                        }

                        switch session.getCognitoTokens() {
                        case .success(let tokens):
                            return tokens.accessToken
                        case .failure(let error):
                            throw error
                        }
                    }
                } catch {
                    try Self.rethrowAsAuthErrorIfNeeded(error, operation: "getTokens")
                }
            },
            signOut: {
                authProviderLogger.info("signOut: started")
                do {
                    let _ = try await withTimeout(seconds: timeout) {
                        await Amplify.Auth.signOut()
                    }
                    authProviderLogger.info("signOut: completed")
                } catch {
                    authProviderLogger.error("signOut: failed (\(String(reflecting: type(of: error)), privacy: .public))")
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
        if let parsed = AppError.parseAuth(error, operation: operation) {
            throw parsed
        }
        throw error.asAppError
    }
}
