//
//  AuthService.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

import Dependencies

struct AuthService: Sendable {
    
    @Dependency(\.authProvider) var authProvider
    
    var userRole: UserRole = .guest
    var accessToken: String?
    
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
    
    mutating func loadAuthData() async -> Result<Empty, AuthError> {
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
    
    mutating func initialize() async -> Result<Empty,AuthError> {
        let initializeResult = await authProvider.initialize()
        if case .failure = initializeResult {
            return initializeResult
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return initializeResult
        case .failure:
            return loadResult
        }
    }
    
    mutating func signIn(username: String, password: String) async -> AuthSignInResult {
        let signInResult = await authProvider.signIn(username, password)
        if case .failure = signInResult {
            return signInResult
        }else if case .newPasswordRequired = signInResult{
            return signInResult
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return signInResult
        case .failure(let error):
            return .failure(error)
        }
    }
    
    mutating func confirmSignIn(username: String, password: String) async-> Result<Empty,AuthError> {
        let confirmSignInResult = await authProvider.confirmSignIn(password)
        if case .failure = confirmSignInResult {
            return confirmSignInResult
        }
        let loadResult = await self.loadAuthData()
        switch loadResult {
        case .success:
            return confirmSignInResult
        case .failure:
            return loadResult
        }
    }
    
    func signOut() async -> Result<Empty,AuthError> {
        let signOutResult = await authProvider.signOut()
        return signOutResult
    }
}
