//
//  AWSCognitoLive.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/05.
//

import AWSMobileClient
import Dependencies


extension AuthProvider: DependencyKey {
    static let liveValue = Self(
        initialize: {
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().initialize { userState, error in
                    if let error = error {
                        continuation.resume(returning: .failure(.unknown("init \(error.localizedDescription)")))
                        return
                    }
                    continuation.resume(returning: .success(Empty()))
                }
            }
        },
        signIn: { username, password in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().signIn(username: username, password: password) { result, error in
                    if let error = error {
                        continuation.resume(returning: .failure(.unknown("signIn \(error.localizedDescription)")))
                        return
                    }
                    guard let result = result else {
                        continuation.resume(returning: .failure(.unknown("result is null")))
                        return
                    }
                    switch result.signInState {
                        case .signedIn:
                            print("Cognito signedIn")
                            continuation.resume(returning: .success)
                        case .newPasswordRequired:
                            print("Cognito newPassword")
                            continuation.resume(returning: .newPasswordRequired)
                        case .smsMFA,
                            .customChallenge,
                            .unknown,
                            .passwordVerifier,
                            .deviceSRPAuth,
                            .devicePasswordVerifier,
                            .adminNoSRPAuth:
                            continuation.resume(returning: .failure(.unknown("Sign-in state: \(result.signInState.rawValue)")))
                    }
                }
            }
        },
        confirmSignIn: { newPassword in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().confirmSignIn(challengeResponse: newPassword) { result, error in
                    if let error = error {
                        print("Password update error: \(error.localizedDescription)")
                        continuation.resume(returning: .failure(.unknown("confirmSignIn \(error.localizedDescription)")))
                    } else {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        getUserRole: {
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().getUserAttributes { attributes, error in
                    if let error = error {
                        continuation.resume(returning: .failure(.unknown("role \(error.localizedDescription)")))
                        return
                    }
                    guard let attributes = attributes,
                          let role = attributes["custom:role"],
                          let username = AWSMobileClient.default().username else {
                        continuation.resume(returning: .success(.guest))
                        return
                    }
                    
                    switch role {
                    case "region":
                        continuation.resume(returning: .success(.region(username)))
                    case "district":
                        continuation.resume(returning: .success(.district(username)))
                    default:
                        continuation.resume(returning: .success(.guest))
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
                    continuation.resume(returning: .success(tokens))
                }
            }
        },
        signOut: {
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().signOut(options: SignOutOptions(invalidateTokens: true))  { error in
                    AWSMobileClient.default().clearKeychain()
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.network(error.localizedDescription)))
                    } else{
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        changePassword: { current, new in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().changePassword(currentPassword: current, proposedPassword: new) { error in
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.unknown(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        resetPassword: { username in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().forgotPassword(username: username) { result, error in
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.unknown(error.localizedDescription)))
                    } else  {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        confirmResetPassword: { username, newPassword, code in
            await withCheckedContinuation { continuation in
                AWSMobileClient
                    .default()
                    .confirmForgotPassword(
                        username: username,
                        newPassword: newPassword,
                        confirmationCode: code
                    ) { result, error in
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.unknown(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        updateEmail: { newEmail in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().updateUserAttributes(attributeMap: ["email": newEmail]) { details, error in
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.unknown(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        },
        confirmEmailChange: { code in
            await withCheckedContinuation { continuation in
                AWSMobileClient.default().confirmUpdateUserAttributes(attributeName: "email", code: code) { error  in
                    if let error = error {
                        continuation.resume(returning: .failure(AuthError.unknown(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: .success(Empty()))
                    }
                }
            }
        }
    )
}
