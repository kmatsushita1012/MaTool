//
//  AWSCognitoLive.swift
//  FesTracking2
//
//  Created by 松下和也 on 202timeout/04/0timeout.
//

import AWSMobileClient
import Dependencies


extension AuthProvider: DependencyKey {
    static let liveValue = {
        let timeout = 5
        return Self(
            initialize: {
                guard let result = (try? await withTimeout(seconds: timeout) {
                    await withCheckedContinuation { continuation in
                        AWSMobileClient.default().initialize { userState, error in
                            if let error = error {
                                continuation.resume(returning: Result<InitializeResult, AuthError>.failure(error.toAuthError()))
                                return
                            }
                            switch userState {
                            case .signedIn:
                                continuation.resume(returning: Result<InitializeResult, AuthError>.success(.signedIn))
                                return
                            default:
                                continuation.resume(returning: Result<InitializeResult, AuthError>.success(.signedOut))
                                return
                            }
                        }
                    }
                }) else {
                    return .failure(.timeout("initialize timeout"))
                }
                return result
            },
            signIn: { username, password in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().signIn(username: username, password: password) { result, error in
                                if let error {
                                    continuation.resume(returning: SignInResponse.failure(error.toAuthError()))
                                    return
                                }
                                guard let result = result else {
                                    continuation.resume(returning: SignInResponse.failure(.unknown("")))
                                    return
                                }
                                switch result.signInState {
                                case .signedIn:
                                    continuation.resume(returning: SignInResponse.success)
                                case .newPasswordRequired:
                                    continuation.resume(returning: SignInResponse.newPasswordRequired)
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
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("signIn"))
                }
            },
            confirmSignIn: { newPassword in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().confirmSignIn(challengeResponse: newPassword) { result, error in
                                if let error = error {
                                    print("Password update error: \(error.localizedDescription)")
                                    continuation.resume(returning: Result<Empty, AuthError>.failure(error.toAuthError()))
                                } else {
                                    continuation.resume(returning: Result<Empty, AuthError>.success(Empty()))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("confirmSignIn"))
                }
            },
            getUserRole: {
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().getUserAttributes { attributes, error in
                                if let error = error {
                                    continuation.resume(returning: Result<UserRole, AuthError>.failure(error.toAuthError()))
                                    return
                                }
                                guard let attributes = attributes,
                                      let role = attributes["custom:role"],
                                      let username = AWSMobileClient.default().username else {
                                    continuation.resume(returning: Result<UserRole, AuthError>.success(.guest))
                                    return
                                }
                                switch role {
                                case "region":
                                    continuation.resume(returning: Result<UserRole, AuthError>.success(.region(username)))
                                    return
                                case "district":
                                    continuation.resume(returning: Result<UserRole, AuthError>.success(.district(username)))
                                    return
                                default:
                                    continuation.resume(returning: Result<UserRole, AuthError>.success(.guest))
                                    return
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("getUserRole"))
                }
            },
            getTokens: {
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().getTokens { tokens, error in
                                if let error = error {
                                    continuation.resume(returning:  Result<Tokens, AuthError>.failure(error.toAuthError()))
                                    return
                                }
                                guard let tokens = tokens else {
                                    continuation.resume(returning:  Result<Tokens, AuthError>.failure(.unknown("notSignedIn")))
                                    return
                                }
                                continuation.resume(returning:  Result<Tokens, AuthError>.success(tokens))
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("getTokens"))
                }
            },
            signOut: {
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().signOut(options: SignOutOptions(invalidateTokens: true))  { error in
                                AWSMobileClient.default().clearKeychain()
                                if let error = error {
                                    continuation.resume(returning: Result<Empty, AuthError>.failure(error.toAuthError()))
                                } else{
                                    continuation.resume(returning: Result<Empty, AuthError>.success(Empty()))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("signout"))
                }
            },
            changePassword: { current, new in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().changePassword(currentPassword: current, proposedPassword: new) { error in
                                if let error {
                                    continuation.resume(returning: Result<Empty, AuthError>.failure(AuthError.unknown(error.localizedDescription)))
                                } else {
                                    continuation.resume(returning: Result<Empty, AuthError>.success(Empty()))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("changePassword"))
                }
            },
            resetPassword: { username in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().forgotPassword(username: username) { result, error in
                                if let error = error {
                                    continuation.resume(returning: Result<Empty,AuthError>.failure(error.toAuthError()))
                                } else  {
                                    continuation.resume(returning: Result<Empty,AuthError>.success(Empty()))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("resetPassword"))
                }
            },
            confirmResetPassword: { username, newPassword, code in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient
                                .default()
                                .confirmForgotPassword(
                                    username: username,
                                    newPassword: newPassword,
                                    confirmationCode: code
                                ) { result, error in
                                    if let error {
                                        continuation.resume(returning: Result<Empty,AuthError>.failure(error.toAuthError()))
                                    } else {
                                        continuation.resume(returning: Result<Empty,AuthError>.success(Empty()))
                                    }
                                }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("confirmResetPassword"))
                }
            },
            updateEmail: { newEmail in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().updateUserAttributes(attributeMap: ["email": newEmail]) { details, error in
                                if let error {
                                    continuation.resume(returning: UpdateEmailResult.failure(error.toAuthError()))
                                    return
                                }
                                guard let details else { return }
                                if details.isEmpty {
                                    continuation.resume(returning: UpdateEmailResult.completed)
                                    return
                                }
                                let  detail = details[0]
                                if let attribute = detail.attributeName,
                                   attribute == "email",
                                   case .email = detail.deliveryMedium,
                                   let destination = detail.destination{
                                    continuation.resume(returning: UpdateEmailResult.verificationRequired(destination: destination))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("updateEmail"))
                }
            },
            confirmUpdateEmail: { code in
                do {
                    let result = try await withTimeout(seconds: timeout) {
                        await withCheckedContinuation { continuation in
                            AWSMobileClient.default().confirmUpdateUserAttributes(attributeName: "email", code: code) { error  in
                                if let error {
                                    continuation.resume(returning: Result<Empty,AuthError>.failure(error.toAuthError()))
                                } else {
                                    continuation.resume(returning: Result<Empty,AuthError>.success(Empty()))
                                }
                            }
                        }
                    }
                    return result
                } catch let error as AuthError {
                    return .failure(error)
                } catch {
                    return .failure(.timeout("confirmUpdateEmail"))
                }
            }
        )
    }()
}
