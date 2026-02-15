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
    var signIn: @Sendable (_ username: String, _ password: String) async -> SignInResponse
    var confirmSignIn: @Sendable (_ newPassword: String) async throws -> Empty
    var getUserRole: @Sendable () async throws -> UserRole
    var getTokens: @Sendable () async throws -> String
    var signOut: @Sendable () async throws -> Empty
    var changePassword: @Sendable (_ current: String, _ new: String) async throws -> Empty
    var resetPassword: @Sendable (_ username: String) async throws -> Empty
    var confirmResetPassword: @Sendable (_ username: String,_ newPassword: String, _ code: String) async throws -> Empty
    var updateEmail: @Sendable (_ newEmail: String) async -> UpdateEmailResult
    var confirmUpdateEmail: @Sendable (_ code: String) async throws -> Empty
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
                    throw AuthError.unknown(error.localizedDescription)
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
                        return .failure(.unknown("Unexpected step: \(result.nextStep)"))
                    }
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("signIn"))
                }
            },
            
            confirmSignIn: { newPassword in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.confirmSignIn(challengeResponse: newPassword)
                    }
                    guard result.isSignedIn else { throw AuthError.unknown("Failed") }
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("confirmSignIn")
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
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("getUserRole")
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
                        throw AuthError.unknown(error.errorDescription)
                    case .none:
                        throw AuthError.unknown("")
                    }
                } catch {
                    throw AuthError.unknown(error.localizedDescription)
                }
            },
            signOut: {
                do {
                    let _ = try await withTimeout(seconds: timeout) {
                        await Amplify.Auth.signOut()
                    }
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("signOut")
                }
            },
            
            changePassword: { current, new in
                do {
                    try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.update(oldPassword: current, to: new)
                    }
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("changePassword")
                }
            },
            
            resetPassword: { username in
                do {
                    _ = try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.resetPassword(for: username)
                    }
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("resetPassword")
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
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("confirmResetPassword")
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
                        return .verificationRequired(destination: "仮")
                    }
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("updateEmail"))
                }
            },
            
            confirmUpdateEmail: { code in
                do {
                    try await withTimeout(seconds: timeout) {
                        try await Amplify.Auth.confirm(userAttribute: .email, confirmationCode: code)
                    }
                    return Empty()
                } catch let error as AuthError {
                    throw error
                } catch {
                    throw AuthError.timeout("confirmUpdateEmail")
                }
            }
        )
    }()
}
