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
    static let liveValue = AuthService()
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

// MARK: - AuthServiceProtocol
protocol AuthServiceProtocol: Sendable {
    func initialize() -> Result<Shared.Empty, AuthError>
    func signIn(_ username: String, password: String) async -> SignInResult
    func confirmSignIn(password: String) async -> Result<UserRole,AuthError>
    func signOut() async -> Result<UserRole, AuthError>
    func getAccessToken() async -> String?
    func changePassword(current: String, new: String) async -> Result<Empty,AuthError>
    func resetPassword(username: String)  async -> Result<Empty,AuthError>
    func confirmResetPassword(username: String, newPassword: String, code: String)  async -> Result<Empty,AuthError>
    func updateEmail(to newEmail: String) async -> UpdateEmailResult
    func confirmUpdateEmail(code: String) async -> Result<Empty,AuthError>
    nonisolated func isValidPassword(_ password: String) -> Bool
    func getUserRole() async -> Result<UserRole, AuthError>
}

// MARK: - AuthService
actor AuthService {
    @Dependency(\.authProvider) var authProvider
    
    private var userRole: UserRole = .guest
    
    func initialize() -> Result<Shared.Empty, AuthError> {
        return authProvider.initialize()
    }
    
    func signIn(_ username: String, password: String) async -> SignInResult {
        let _ = await authProvider.signOut()
        let result = await authProvider.signIn(username, password)
        switch result {
        case .failure(let error):
            return .failure(error)
        case .newPasswordRequired:
            return .newPasswordRequired
        case .success:
            let userRoleResult = await getUserRole()
            switch userRoleResult{
            case .success(let userRole):
                return .success(userRole)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
    
    func confirmSignIn(password: String) async -> Result<UserRole,AuthError> {
        let confirmSignInResult = await authProvider.confirmSignIn(password)
        if case .failure(let error) = confirmSignInResult {
            let _ = await authProvider.signOut()
            return .failure(error)
        }
        let userRoleResult = await authProvider.getUserRole()
        return userRoleResult
    }
    
    func signOut() async -> Result<UserRole, AuthError> {
        let signOutResult = await authProvider.signOut()
        if case .failure(let error) = signOutResult{
            return .failure(error)
        }
        userRole = .guest
        return .success(userRole)
    }
    
    func getAccessToken() async -> String? {
        if userRole == .guest {
            return nil
        }
        let result = await authProvider.getTokens()
        switch result {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    func changePassword(current: String, new: String) async -> Result<Empty,AuthError> {
        return await authProvider.changePassword(current, new)
    }
    
    func resetPassword(username: String)  async -> Result<Empty,AuthError> {
        return await authProvider.resetPassword(username)
    }
    
    func confirmResetPassword(username: String, newPassword: String, code: String)  async -> Result<Empty,AuthError> {
        return await authProvider.confirmResetPassword(
            username,
            newPassword,
            code
        )
    }
    
    func updateEmail(to newEmail: String) async -> UpdateEmailResult {
        return await authProvider.updateEmail(newEmail)
    }
    
    func confirmUpdateEmail(code: String) async -> Result<Empty,AuthError> {
        return await authProvider.confirmUpdateEmail(code)
    }
    
    nonisolated func isValidPassword(_ password: String) -> Bool {
        let lengthRule = password.count >= 8
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil

        return lengthRule && hasNumber && hasUppercase && hasLowercase
    }
    
    func getUserRole() async -> Result<UserRole, AuthError> {
        let userRoleResult = await authProvider.getUserRole()
        switch userRoleResult {
        case .success(let value):
            userRole = value
            return .success(value)
        case .failure( _):
            let _ = await authProvider.signOut()
            return .success(.guest)
        }
    }
}
