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
                            continuation.resume(returning: Result<UserState?, AWSCognitoError>.failure(AWSCognitoError.network(error.localizedDescription)))
                        } else {
                            continuation.resume(returning: Result.success(userState))
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
                            continuation.resume(returning: Result<SignInResult, AWSCognitoError>.failure(AWSCognitoError.network(error.localizedDescription)))
                        } else if let result = result {
                            continuation.resume(returning: Result.success(result))
                        } else {
                            continuation.resume(returning: Result<SignInResult, AWSCognitoError>.failure(AWSCognitoError.unknown("Unknown")))
                        }
                    }
                }
            } catch  {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
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
                            continuation.resume(returning: Result<Void, AWSCognitoError>.failure(AWSCognitoError.network(error.localizedDescription)))
                        } else{
                            continuation.resume(returning: .success(()))
                        }
                    }
                }
            } catch {
                return Result.failure(AWSCognitoError.unknown("Unknown"))
            }
        }
    )
}

