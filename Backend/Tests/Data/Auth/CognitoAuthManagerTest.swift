//
//  CognitoAuthManagerTest.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/22.
//

import Testing
import Foundation
import CasePaths
import Dependencies
@preconcurrency import AWSCognitoIdentityProvider
@testable import Backend
import Shared

struct CognitoAuthManagerTest {
    let factory: AuthManagerFactory
    @Dependency(Environment.self) var env
    
    init() {
        @Dependency(Environment.self) var env
        self.factory = {
            let client = try await CognitoIdentityProviderClient()
            return CognitoAuthManager(client: client, userPoolId: env.cognitoPoolId)
        }
    }
    
    @Test(.disabled("統合テスト")) func test_create_正常() async throws {
        let username = "integration-test-\(UUID().uuidString.prefix(6))"
        let subject = try await factory()
        
        let result: UserRole = try await subject.create(username: username, email: env.cognitoTestEmail)
        
        
        #expect(result.is( \.district) == true)
        let usernameCreateResult : String? = result[case: \.district]
        #expect(usernameCreateResult?.lowercased() == username.lowercased())
        
        
        let getResult: UserRole = try await subject.get(username: username)
        
        #expect(getResult.is( \.district) == true)
        let usernameGetResult : String? = getResult[case: \.district]
        #expect(usernameGetResult?.lowercased() == username.lowercased())
    }
}

 
