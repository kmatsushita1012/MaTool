//
//  CognitoAuthManager.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Shared
@preconcurrency import AWSCognitoIdentityProvider

struct CognitoAuthManager: AuthManager {

    private let client: CognitoIdentityProviderClient
    private let userPoolId: String

    init(client: CognitoIdentityProviderClient, userPoolId: String) {
        self.client = client
        self.userPoolId = userPoolId
    }
    
    init() async throws {
        self.client = try await .init()
        self.userPoolId = ""
    }

    func create(username: String, email: String) async throws -> UserRole {
        // リクエスト作成
        let input = AdminCreateUserInput(
            desiredDeliveryMediums: [.email],
            forceAliasCreation: false,
            userAttributes: [
                .init(name: "email", value: email),
                .init(name: "email_verified", value: "true"),
                .init(name: "custom:role", value: "district")
            ],
            userPoolId: userPoolId,
            username: username
        )
        
        //登録
        let response = try await client.adminCreateUser(input: input)
        
        // レスポンスを確認
        guard let userReponse = response.user else { throw APIError.unauthorized()}
        let id = userReponse.username
        let attributes = userReponse.attributes
        let role = attributes?.first{ $0.name == "custom:role"}
        guard let id, role?.value == "district" else { throw APIError.unauthorized() }
        let user: UserRole = .district(id)
        return user
    }

    func get(username: String) async throws -> UserRole {
        let input = AdminGetUserInput(
            userPoolId: userPoolId,
            username: username
        )
        let response = try await client.adminGetUser(input: input)
        
        let id = response.username
        let attributes = response.userAttributes
        let role = attributes?.first{ $0.name == "custom:role"}
        guard let id, role?.value == "district" else { throw APIError.unauthorized() }
        let user: UserRole = .district(id)
        return user
    }
}

