//
//  AuthService.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies
import Shared

// MARK: - Dependencies
enum AuthServiceKey: DependencyKey {
    static let liveValue: AuthServiceProtocol = AuthService()
}

extension DependencyValues {
    var authService: AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// MARK: - AuthServiceProtocol
protocol AuthServiceProtocol: Sendable {
    nonisolated func initialize() throws
    func signIn(_ username: String, password: String) async -> SignInResult
    func confirmSignIn(password: String) async throws -> UserRole
    func signOut() async throws -> UserRole
    func getAccessToken() async -> String?
    func changePassword(current: String, new: String) async throws -> Empty
    func resetPassword(username: String)  async throws -> Empty
    func confirmResetPassword(username: String, newPassword: String, code: String)  async throws -> Empty
    func updateEmail(to newEmail: String) async -> UpdateEmailResult
    func confirmUpdateEmail(code: String) async throws -> Empty
    nonisolated func isValidPassword(_ password: String) -> Bool
    func getUserRole() async throws -> UserRole
}

// MARK: - AuthService
actor AuthService: AuthServiceProtocol {
    @Dependency(\.authProvider) var authProvider
    
    private var userRole: UserRole = .guest
    
    nonisolated func initialize() throws {
        @Dependency(\.authProvider) var authProvider
        return try authProvider.initialize()
    }
    
    func signIn(_ username: String, password: String) async -> SignInResult {
        try? await authProvider.signOut()
        let result = await authProvider.signIn(username, password)
        switch result {
        case .failure(let error):
            return .failure(error)
        case .newPasswordRequired:
            return .newPasswordRequired
        case .success:
            do {
                let userRole = try await getUserRole()
                return .success(userRole)
            } catch let error as AuthError {
                return .failure(error)
            } catch {
                return .failure(.unknown(error.localizedDescription))
            }
        }
    }
    
    func confirmSignIn(password: String) async throws -> UserRole {
        do {
            _ = try await authProvider.confirmSignIn(password)
            return try await authProvider.getUserRole()
        } catch {
            try? await authProvider.signOut()
            throw error
        }
    }
    
    func signOut() async throws -> UserRole {
        _ = try await authProvider.signOut()
        userRole = .guest
        return userRole
    }
    
    func getAccessToken() async -> String? {
        if userRole == .guest {
            return nil
        }
        return try? await authProvider.getTokens()
    }
    
    func changePassword(current: String, new: String) async throws -> Empty {
        return try await authProvider.changePassword(current, new)
    }
    
    func resetPassword(username: String)  async throws -> Empty {
        return try await authProvider.resetPassword(username)
    }
    
    func confirmResetPassword(username: String, newPassword: String, code: String)  async throws -> Empty {
        return try await authProvider.confirmResetPassword(
            username,
            newPassword,
            code
        )
    }
    
    func updateEmail(to newEmail: String) async -> UpdateEmailResult {
        return await authProvider.updateEmail(newEmail)
    }
    
    func confirmUpdateEmail(code: String) async throws -> Empty {
        return try await authProvider.confirmUpdateEmail(code)
    }
    
    nonisolated func isValidPassword(_ password: String) -> Bool {
        let lengthRule = password.count >= 8
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil

        return lengthRule && hasNumber && hasUppercase && hasLowercase
    }
    
    func getUserRole() async throws -> UserRole {
        do {
            let value = try await authProvider.getUserRole()
            userRole = value
            return value
        } catch {
            try? await authProvider.signOut()
            userRole = .guest
            return .guest
        }
    }
}

@available(*, deprecated, message: "Use async throws APIs instead of Result wrappers.")
extension AuthServiceProtocol {
    func confirmSignInResult(password: String) async -> Result<UserRole, AuthError> {
        do {
            return .success(try await confirmSignIn(password: password))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func signOutResult() async -> Result<UserRole, AuthError> {
        do {
            return .success(try await signOut())
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func changePasswordResult(current: String, new: String) async -> Result<Empty, AuthError> {
        do {
            return .success(try await changePassword(current: current, new: new))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func resetPasswordResult(username: String) async -> Result<Empty, AuthError> {
        do {
            return .success(try await resetPassword(username: username))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func confirmResetPasswordResult(username: String, newPassword: String, code: String) async -> Result<Empty, AuthError> {
        do {
            return .success(try await confirmResetPassword(username: username, newPassword: newPassword, code: code))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func confirmUpdateEmailResult(code: String) async -> Result<Empty, AuthError> {
        do {
            return .success(try await confirmUpdateEmail(code: code))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func getUserRoleResult() async -> Result<UserRole, AuthError> {
        do {
            return .success(try await getUserRole())
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
}
