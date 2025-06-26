//
//  AuthService.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies

actor AuthService {
    
    @Dependency(\.authProvider) var authProvider
    
    var userRole: UserRole = .guest
    var accessToken: String? = nil
    
    private func fetchAuthData() async -> Result<(String?, UserRole), AuthError> {
        async let tokenResult = authProvider.getTokens()
        async let userRoleResult = authProvider.getUserRole()

        let (token, userRole) = await (tokenResult, userRoleResult)
        
        switch (token, userRole) {
        case (.success(let token), .success(let role)):
            return .success((token.accessToken?.tokenString, role))
        case (.failure(let err), _):
            return .failure(err)
        case (_, .failure(let err)):
            return .failure(err)
        }
    }
    
    private func loadAuthData() async -> Result<Empty, AuthError> {
        let result = await fetchAuthData()
        switch result {
        case .success(let (token, role)):
            self.accessToken = token
            self.userRole = role
            return .success(Empty())
        case .failure(let err):
            return .failure(err)
        }
    }
    
    func initialize() async -> Result<UserRole,AuthError> {
        let initializeResult = await authProvider.initialize()
        if case .failure(let error) = initializeResult {
            return .failure(error)
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return .success(userRole)
        case .failure(let error):
            let _ = await signOut()
            return .failure(error)
        }
    }
    
    func signIn(_ username: String, password: String) async -> SignInResult {
        let signInResult = await authProvider.signIn(username, password)
        if case .failure(let error) = signInResult {
            return .failure(error)
        }else if case .newPasswordRequired = signInResult{
            return .newPasswordRequired
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return .success(userRole)
        case .failure(let error):
            let _ = await signOut()
            return .failure(error)
        }
    }
    
    func confirmSignIn(password: String) async-> Result<UserRole,AuthError> {
        let confirmSignInResult = await authProvider.confirmSignIn(password)
        if case .failure(let error) = confirmSignInResult {
            return .failure(error)
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return .success(userRole)
        case .failure(let error):
            let _ = await signOut()
            return .failure(error)
        }
    }
    
    func signOut() async -> Result<UserRole, AuthError> {
        let signOutResult = await authProvider.signOut()
        if case .failure(let error) = signOutResult{
            return .failure(error)
        }
        accessToken = nil
        userRole = .guest
        return .success(userRole)
    }
    
    func getAccessToken() async -> String? {
        return accessToken
    }
    
    func getUserRole() async -> UserRole {
        return userRole
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
