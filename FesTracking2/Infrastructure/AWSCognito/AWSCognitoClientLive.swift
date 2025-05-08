//
//  AWSCognitoLive.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import AWSMobileClient
import Dependencies

extension AWSCognitoClient: DependencyKey {
    static let liveValue = Self(
        initialize: {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AWSMobileClient.default().initialize { userState, error in
                        if let error = error {
                            continuation.resume(returning: .failure(AWSCognitoError.network(error.localizedDescription)))
                        } else {
                            switch userState {
                            case .signedIn:
                                continuation.resume(returning: .success(true))
                            case .signedOut,.signedOutFederatedTokensInvalid,.signedOutUserPoolsTokenInvalid,.none,.some:
                                continuation.resume(returning: .success(false))
                            }
                            
                        }
                    }
                }
            } catch  {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
            }
        },
        signIn: { username, password in
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AWSMobileClient.default().signIn(username: username, password: password) { result, error in
                        if let error = error {
                            continuation.resume(returning: .failure(AWSCognitoError.network(error.localizedDescription)))
                        } else if let result = result {
                            switch result.signInState{
                            case .signedIn:
                                continuation.resume(returning: Result.success(true))
                            default:
                                continuation.resume(returning: Result.success(false))
                            }
                            
                        } else {
                            continuation.resume(returning:.failure(AWSCognitoError.unknown("Unknown")))
                        }
                    }
                }
            } catch  {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
            }
        },
        getUserId: {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AWSMobileClient.default().getUserAttributes { attributes, error in
                        if let error = error {
                            continuation.resume(returning: .failure(AWSCognitoError.network(error.localizedDescription)))
                        } else if let attributes = attributes {
                            // attributesからusernameを取得
                            if let username = attributes["sub"] {
                                continuation.resume(returning: .success(username))
                            } else {
                                continuation.resume(returning: .failure(AWSCognitoError.unknown("Username not found")))
                            }
                        } else {
                            continuation.resume(returning: .failure(AWSCognitoError.unknown("Unknown error")))
                        }
                    }
                }
            } catch {
                return .failure(AWSCognitoError.unknown("Unknown"))
            }
        },
        getTokens: {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AWSMobileClient.default().getTokens { tokens, error in
                        if let error = error {
                            continuation.resume(returning: Result<Tokens, AWSCognitoError>.failure(AWSCognitoError.network(error.localizedDescription)))
                        } else if let tokens = tokens {
                            continuation.resume(returning: Result.success(tokens))
                        } else {
                            continuation.resume(returning: Result.failure(AWSCognitoError.unknown("Unknown")))
                        }
                    }
                }
            } catch {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
            }
        },
        signOut: {
            do{
                return try await withCheckedThrowingContinuation { continuation in
                    AWSMobileClient.default().signOut { error in
                        if let error = error {
                            continuation.resume(returning: .failure(AWSCognitoError.network(error.localizedDescription)))
                        } else{
                            continuation.resume(returning: .success(true))
                        }
                    }
                }
            } catch {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
            }
        }
    )
}

