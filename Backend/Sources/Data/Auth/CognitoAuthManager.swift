//
//  CognitoAuthManager.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/11/21.
//

import Dependencies
import Crypto
import Foundation
import Shared
@preconcurrency import AWSCognitoIdentityProvider

/// External AWS calls are captured at a single injectable boundary for deterministic unit tests.
struct CognitoAuthService: Sendable {
    var create: @Sendable (AdminCreateUserInput) async throws -> AdminCreateUserOutput
    var disable: @Sendable (AdminDisableUserInput) async throws -> AdminDisableUserOutput
    var delete: @Sendable (AdminDeleteUserInput) async throws -> AdminDeleteUserOutput
    var getByToken: @Sendable (GetUserInput) async throws -> GetUserOutput
    var getByUsername: @Sendable (AdminGetUserInput) async throws -> AdminGetUserOutput
    var signUp: (@Sendable (SignUpInput) async throws -> SignUpOutput)?
    var confirmSignUp: (@Sendable (ConfirmSignUpInput) async throws -> ConfirmSignUpOutput)?

    init(
        create: @escaping @Sendable (AdminCreateUserInput) async throws -> AdminCreateUserOutput,
        disable: @escaping @Sendable (AdminDisableUserInput) async throws -> AdminDisableUserOutput,
        delete: @escaping @Sendable (AdminDeleteUserInput) async throws -> AdminDeleteUserOutput,
        getByToken: @escaping @Sendable (GetUserInput) async throws -> GetUserOutput,
        getByUsername: @escaping @Sendable (AdminGetUserInput) async throws -> AdminGetUserOutput,
        signUp: (@Sendable (SignUpInput) async throws -> SignUpOutput)? = nil,
        confirmSignUp: (@Sendable (ConfirmSignUpInput) async throws -> ConfirmSignUpOutput)? = nil
    ) {
        self.create = create
        self.disable = disable
        self.delete = delete
        self.getByToken = getByToken
        self.getByUsername = getByUsername
        self.signUp = signUp
        self.confirmSignUp = confirmSignUp
    }

    init(client: CognitoIdentityProviderClient) {
        self.init(
            create: { try await client.adminCreateUser(input: $0) },
            disable: { try await client.adminDisableUser(input: $0) },
            delete: { try await client.adminDeleteUser(input: $0) },
            getByToken: { try await client.getUser(input: $0) },
            getByUsername: { try await client.adminGetUser(input: $0) },
            signUp: { try await client.signUp(input: $0) },
            confirmSignUp: { try await client.confirmSignUp(input: $0) }
        )
    }
}

struct CognitoAuthManager: AuthManager {
    private let service: CognitoAuthService
    private let userPoolId: String
    private let advertiserAppClientId: String?
    private let advertiserAppClientSecret: String?

    init(
        client: CognitoIdentityProviderClient,
        userPoolId: String,
        advertiserAppClientId: String? = nil,
        advertiserAppClientSecret: String? = nil
    ) {
        self.init(
            service: CognitoAuthService(client: client),
            userPoolId: userPoolId,
            advertiserAppClientId: advertiserAppClientId,
            advertiserAppClientSecret: advertiserAppClientSecret
        )
    }

    init(
        service: CognitoAuthService,
        userPoolId: String,
        advertiserAppClientId: String? = nil,
        advertiserAppClientSecret: String? = nil
    ) {
        self.service = service
        self.userPoolId = userPoolId
        self.advertiserAppClientId = advertiserAppClientId
        self.advertiserAppClientSecret = advertiserAppClientSecret
    }

    init() async throws {
        @Dependency(Environment.self) var env
        let client = try await CognitoIdentityProviderClient()
        self.init(
            client: client,
            userPoolId: env.cognitoPoolId,
            advertiserAppClientId: env.advertiserCognitoAppClientId,
            advertiserAppClientSecret: env.advertiserCognitoAppClientSecret
        )
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

    func signUp(email: String, password: String) async throws {
        guard let advertiserAppClientId, let advertiserAppClientSecret else {
            throw Error.internalServerError("広告主登録が設定されていません。")
        }
        let input = SignUpInput(
            clientId: advertiserAppClientId,
            password: password,
            secretHash: secretHash(username: email, clientId: advertiserAppClientId, clientSecret: advertiserAppClientSecret),
            userAttributes: [
                .init(name: "email", value: email),
                .init(name: "custom:role", value: "advertiser")
            ],
            username: email
        )

        do {
            guard let signUp = service.signUp else {
                throw Error.internalServerError("広告主登録が設定されていません。")
            }
            _ = try await signUp(input)
        } catch is UsernameExistsException {
            throw Error.conflict("このメールアドレスは登録済みです。")
        } catch is AliasExistsException {
            throw Error.conflict("このメールアドレスは登録済みです。")
        } catch is InvalidPasswordException {
            throw Error.badRequest("パスワードが要件を満たしていません。")
        } catch is InvalidParameterException {
            throw Error.badRequest("登録情報が正しくありません。")
        } catch is TooManyRequestsException {
            throw Error.tooManyRequests("登録要求が集中しています。時間をおいて再試行してください。")
        } catch is LimitExceededException {
            throw Error.tooManyRequests("登録要求が集中しています。時間をおいて再試行してください。")
        } catch {
            throw Error.internalServerError("登録処理に失敗しました。時間をおいて再試行してください。")
        }
    }

    func confirmSignUp(email: String, confirmationCode: String) async throws {
        guard let advertiserAppClientId, let advertiserAppClientSecret else {
            throw Error.internalServerError("広告主登録が設定されていません。")
        }
        let input = ConfirmSignUpInput(
            clientId: advertiserAppClientId,
            confirmationCode: confirmationCode,
            secretHash: secretHash(username: email, clientId: advertiserAppClientId, clientSecret: advertiserAppClientSecret),
            username: email
        )

        do {
            guard let confirmSignUp = service.confirmSignUp else {
                throw Error.internalServerError("広告主登録が設定されていません。")
            }
            _ = try await confirmSignUp(input)
        } catch is CodeMismatchException {
            throw Error.badRequest("確認コードが正しくありません。")
        } catch is ExpiredCodeException {
            throw Error.badRequest("確認コードの有効期限が切れています。")
        } catch is UserNotFoundException {
            throw Error.badRequest("登録情報または確認コードが正しくありません。")
        } catch is NotAuthorizedException {
            throw Error.conflict("このアカウントは確認済みか、確認できない状態です。")
        } catch is TooManyRequestsException {
            throw Error.tooManyRequests("確認要求が集中しています。時間をおいて再試行してください。")
        } catch is LimitExceededException {
            throw Error.tooManyRequests("確認要求が集中しています。時間をおいて再試行してください。")
        } catch {
            throw Error.internalServerError("確認処理に失敗しました。時間をおいて再試行してください。")
        }
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
        switch role {
        case .some("district"):
            guard let id else { throw Error.unauthorized() }
            return .district(id)
        case .some("region"):
            guard let id else { throw Error.unauthorized() }
            return .headquarter(id)
        case .some("advertiser"):
            guard let sub, !sub.isEmpty,
                  attributes?.first(where: { $0.name == "email_verified" })?.value == "true" else {
                throw Error.unauthorized()
            }
            return .advertiser(sub)
        case nil:
            throw Error.unauthorized("ユーザーの権限が設定されていません。")
        default:
            throw Error.unauthorized()
        }
    }

    private func secretHash(username: String, clientId: String, clientSecret: String) -> String {
        let key = SymmetricKey(data: Data(clientSecret.utf8))
        let message = Data("\(username)\(clientId)".utf8)
        let digest = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(digest).base64EncodedString()
    }
}
