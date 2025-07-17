//
//  AuthService.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies

struct AuthService: Sendable {
    
    @Dependency(\.authProvider) var authProvider
    
    func initialize() async -> Result<UserRole,AuthError> {
        let initializeResult = await authProvider.initialize()
        if case .failure(let error) = initializeResult {
            return .failure(error)
        }
        let userRoleResult = await authProvider.getUserRole()
        switch userRoleResult {
        case .success(let value):
            return .success(value)
        case .failure( _):
            let _ = await authProvider.signOut()
            return .success(.guest)
        }
    }
    
    func signIn(_ username: String, password: String) async -> SignInResult {
        let signInResult = await authProvider.signIn(username, password)
        if case .failure(let error) = signInResult {
            return .failure(error)
        }else if case .newPasswordRequired = signInResult{
            return .newPasswordRequired
        }
        let userRoleResult = await authProvider.getUserRole()
        switch userRoleResult {
        case .success(let value):
            return .success(value)
        case .failure( _):
            let _ = await authProvider.signOut()
            return .success(.guest)
        }
    }
    
    func confirmSignIn(password: String) async-> Result<UserRole,AuthError> {
        let confirmSignInResult = await authProvider.confirmSignIn(password)
        if case .failure(let error) = confirmSignInResult {
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
        return .success(.guest)
    }
    
    func getAccessToken() async -> String? {
        let result = await authProvider.getTokens()
        switch result {
        case .success(let value):
            return value.accessToken?.tokenString
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
    func updateEmail(to newEmail: String) async -> Result<Empty,AuthError> {
        return await authProvider.updateEmail(newEmail)
    }
    func confirmUpdateEmail(code: String) async -> Result<Empty,AuthError> {
        return await authProvider.confirmUpdateEmail(code)
    }
    func isValidPassword(_ password: String) -> Bool {
        let lengthRule = password.count >= 8
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil

        return lengthRule && hasNumber && hasUppercase && hasLowercase
    }
}

private enum AuthServiceKey: DependencyKey {
    static let liveValue = AuthService()
    static let testValue = AuthService()
    static let previewValue = AuthService()
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}
