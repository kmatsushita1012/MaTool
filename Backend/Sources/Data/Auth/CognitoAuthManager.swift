//
//  CognitoAuthManager.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Shared
@preconcurrency import AWSCognitoIdentityProvider

/// External AWS calls are captured at a single injectable boundary for deterministic unit tests.
struct CognitoAuthService: Sendable {
    var create: @Sendable (AdminCreateUserInput) async throws -> AdminCreateUserOutput
    var disable: @Sendable (AdminDisableUserInput) async throws -> AdminDisableUserOutput
    var delete: @Sendable (AdminDeleteUserInput) async throws -> AdminDeleteUserOutput
    var getByToken: @Sendable (GetUserInput) async throws -> GetUserOutput
    var getByUsername: @Sendable (AdminGetUserInput) async throws -> AdminGetUserOutput

    init(
        create: @escaping @Sendable (AdminCreateUserInput) async throws -> AdminCreateUserOutput,
        disable: @escaping @Sendable (AdminDisableUserInput) async throws -> AdminDisableUserOutput,
        delete: @escaping @Sendable (AdminDeleteUserInput) async throws -> AdminDeleteUserOutput,
        getByToken: @escaping @Sendable (GetUserInput) async throws -> GetUserOutput,
        getByUsername: @escaping @Sendable (AdminGetUserInput) async throws -> AdminGetUserOutput
    ) {
        self.create = create
        self.disable = disable
        self.delete = delete
        self.getByToken = getByToken
        self.getByUsername = getByUsername
    }

    init(client: CognitoIdentityProviderClient) {
        self.init(
            create: { try await client.adminCreateUser(input: $0) },
            disable: { try await client.adminDisableUser(input: $0) },
            delete: { try await client.adminDeleteUser(input: $0) },
            getByToken: { try await client.getUser(input: $0) },
            getByUsername: { try await client.adminGetUser(input: $0) }
        )
    }
}

struct CognitoAuthManager: AuthManager {
    private let service: CognitoAuthService
    private let userPoolId: String

    init(client: CognitoIdentityProviderClient, userPoolId: String) {
        self.init(service: CognitoAuthService(client: client), userPoolId: userPoolId)
    }

    init(service: CognitoAuthService, userPoolId: String) {
        self.service = service
        self.userPoolId = userPoolId
    }

    init() async throws {
        @Dependency(Environment.self) var env
        let client = try await CognitoIdentityProviderClient()
        self.init(client: client, userPoolId: env.cognitoPoolId)
    }

    func create(username: String, email: String) async throws -> UserRole {
        let input = makeCreateInput(
            username: username,
            email: email,
            messageAction: nil
        )
        let response = try await service.create(input)
        return try parseCreatedUser(response: response)
    }

    func delete(username: String) async throws {
        let disableInput = AdminDisableUserInput(
            userPoolId: userPoolId,
            username: username
        )
        _ = try await service.disable(disableInput)

        let deleteInput = AdminDeleteUserInput(
            userPoolId: userPoolId,
            username: username
        )
        _ = try await service.delete(deleteInput)
    }
    
    func get(accessToken: String) async throws -> UserRole {
        let input = GetUserInput(
            accessToken: accessToken
        )
        let response = try await service.getByToken(input)
        
        let user = try parseUserRole(attributes: response.userAttributes, id: response.username)
        return user
    }

    func get(username: String) async throws -> UserRole {
        let input = AdminGetUserInput(
            userPoolId: userPoolId,
            username: username
        )
        let response = try await service.getByUsername(input)
        
        let user = try parseUserRole(attributes: response.userAttributes, id: response.username)
        return user
    }

    private func makeCreateInput(
        username: String,
        email: String,
        messageAction: CognitoIdentityProviderClientTypes.MessageActionType?
    ) -> AdminCreateUserInput {
        AdminCreateUserInput(
            desiredDeliveryMediums: [.email],
            forceAliasCreation: false,
            messageAction: messageAction,
            userAttributes: [
                .init(name: "email", value: email),
                .init(name: "email_verified", value: "true"),
                .init(name: "custom:role", value: "district")
            ],
            userPoolId: userPoolId,
            username: username
        )
    }

    private func parseCreatedUser(response: AdminCreateUserOutput) throws -> UserRole {
        guard let userReponse = response.user else { throw Error.unauthorized() }
        let id = userReponse.username
        let attributes = userReponse.attributes
        let role = attributes?.first { $0.name == "custom:role" }
        guard let id, role?.value == "district" else { throw Error.unauthorized() }
        return .district(id)
    }
    
    private func parseUserRole(attributes: [CognitoIdentityProviderClientTypes.AttributeType]?, id: String?) throws -> UserRole {
        let role = attributes?.first{ $0.name == "custom:role"}?.value
        guard let id, let role else { throw Error.unauthorized() }
        switch role {
        case "district":
            return .district(id)
        case "region":
            return .headquarter(id)
        default:
            throw Error.unauthorized()
        }
    }
}
