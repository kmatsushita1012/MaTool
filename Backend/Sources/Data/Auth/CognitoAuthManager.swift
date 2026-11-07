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
        @Dependency(Environment.self) var env
        self.client = try await .init()
        self.userPoolId = env.cognitoPoolId
    }

    func create(username: String, email: String) async throws -> UserRole {
        let input = makeCreateInput(
            username: username,
            email: email,
            messageAction: nil
        )
        let response = try await client.adminCreateUser(input: input)
        return try parseCreatedUser(response: response)
    }

    func delete(username: String) async throws {
        let disableInput = AdminDisableUserInput(
            userPoolId: userPoolId,
            username: username
        )
        _ = try await client.adminDisableUser(input: disableInput)

        let deleteInput = AdminDeleteUserInput(
            userPoolId: userPoolId,
            username: username
        )
        _ = try await client.adminDeleteUser(input: deleteInput)
    }
    
    func get(accessToken: String) async throws -> UserRole {
        let input = GetUserInput(
            accessToken: accessToken
        )
        let response = try await client.getUser(input: input)
        
        let user = try parseUserRole(attributes: response.userAttributes, id: response.username)
        return user
    }

    func get(username: String) async throws -> UserRole {
        let input = AdminGetUserInput(
            userPoolId: userPoolId,
            username: username
        )
        let response = try await client.adminGetUser(input: input)
        
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
        let role = attributes?.first { $0.name == "custom:role" }?.value
        let sub = attributes?.first { $0.name == "sub" }?.value
        guard let id else { throw Error.unauthorized() }
        switch role {
        case .some("district"):
            return .district(id)
        case .some("region"):
            return .headquarter(id)
        case .some("advertiser"):
            guard let sub, !sub.isEmpty,
                  attributes?.first(where: { $0.name == "email_verified" })?.value == "true" else {
                throw Error.unauthorized()
            }
            return .advertiser(sub)
        case nil:
            // Unclassified, verified Cognito users are advertisers. The app client must not
            // be allowed to write custom:role so it cannot grant itself an admin role.
            guard let sub, !sub.isEmpty,
                  attributes?.first(where: { $0.name == "email_verified" })?.value == "true" else {
                throw Error.unauthorized()
            }
            return .advertiser(sub)
        default:
            throw Error.unauthorized()
        }
    }
}
