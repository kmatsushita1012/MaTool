//
//  AuthManagerMock.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/24.
//

@testable import Backend
import Shared

final class AuthManagerMock: AuthManager, @unchecked Sendable {
    
    init(
        createHandler: ((String, String) throws -> UserRole)? = nil,
        getAccessTokenHandler: ((String) throws -> UserRole)? = nil,
        getUserNameHandler: ((String) throws -> UserRole)? = nil
    ) {
        self.createHandler = createHandler
        self.getAccessTokenHandler = getAccessTokenHandler
        self.getUserNameHandler = getUserNameHandler
    }
    
    var createCallCount: Int = 0
    var createHandler: ((String, String) throws -> UserRole)?
    func create(username: String, email: String) async throws -> UserRole {
        createCallCount+=1
        guard let createHandler else { throw TestError.unimplemented }
        return try createHandler(username, email)
    }
    
    var getAccessTokenCallCount: Int = 0
    var getAccessTokenHandler: ((String) throws -> UserRole)?
    func get(accessToken: String) async throws -> UserRole {
        getAccessTokenCallCount+=1
        guard let getAccessTokenHandler else { throw TestError.unimplemented }
        return try getAccessTokenHandler(accessToken)
    }
    
    
    var getUserNameCallCount: Int = 0
    var getUserNameHandler: ((String) throws -> UserRole)?
    func get(username: String) async throws -> UserRole {
        getUserNameCallCount+=1
        guard let getUserNameHandler else { throw TestError.unimplemented }
        return try getUserNameHandler(username)
    }
    
    
}
