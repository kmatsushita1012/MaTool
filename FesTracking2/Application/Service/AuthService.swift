//
//  AuthService.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies

actor AuthService {
    
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
        case .failure(let _):
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
        case .failure(let _):
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
        switch userRoleResult {
        case .success(let value):
            return .success(value)
        case .failure(let _):
            let _ = await authProvider.signOut()
            return .success(.guest)
        }
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
