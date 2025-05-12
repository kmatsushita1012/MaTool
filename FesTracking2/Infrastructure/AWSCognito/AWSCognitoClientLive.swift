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
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().initialize { userState, error in
                    if let error = error {
                        continuation.resume(returning: .failure(.unknown("init \(error.localizedDescription)")))
                        return
                    }
                    guard let _ = userState else {
                        continuation.resume(returning: .success(.guest))
                        return
                    }

                    getRole { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        },
        signIn: { username, password in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().signIn(username: username, password: password) { result, error in
                    if let error = error {
                        continuation.resume(returning: .failure(.unknown("sing \(error.localizedDescription)")))
                        return
                    }

                    getRole { roleResult in
                        continuation.resume(returning: roleResult)
                    }
                }
            }
        },
        getTokens: {
            await withCheckedContinuation { continuation in
                    AWSMobileClient.default().getTokens { tokens, error in
                        if let error = error {
                            continuation.resume(returning: .failure(.unknown(error.localizedDescription)))
                            return
                        }

                        guard let tokens = tokens else {
                            continuation.resume(returning: .failure(.unknown("notSignedIn")))
                            return
                        }
//
//                        let result = Tokens(
//                            idToken: tokens.idToken?.tokenString ?? "",
//                            accessToken: tokens.accessToken?.tokenString ?? "",
//                            refreshToken: tokens.refreshToken?.tokenString ?? ""
//                        )
                        continuation.resume(returning: .success(tokens))
                    }
                }
        },
        signOut: {
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().signOut { error in
                    if let error = error {
                        continuation.resume(returning: .failure(AWSCognitoError.network(error.localizedDescription)))
                    } else{
                        continuation.resume(returning: .success(true))
                    }
                }
            }
        }
    )
    
    static func getRole(completion: @escaping (Result<UserRole, AWSCognitoError>) -> Void) {
        AWSMobileClient.default().getUserAttributes { attributes, error in
            if let error = error {
                completion(.failure(.unknown("role \(error.localizedDescription)")))
                return
            }
            guard let attributes = attributes,
                  let sub = attributes["sub"],
                  let role = attributes["custom:role"] else {
                
                completion(.success(.guest))
                return
            }

            switch role {
            case "region":
                completion(.success(.region(sub)))
            case "district":
                completion(.success(.district(sub)))
            default:
                completion(.success(.guest))
            }
        }
    }

}

