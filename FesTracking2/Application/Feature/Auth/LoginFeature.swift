//
//  AuthFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture
import AWSMobileClient

@Reducer
struct LoginFeature {
    @ObservableState
    struct State: Equatable {
        var username: String = ""
        var password: String = ""
        var errorMessage: String?
    }

    enum Action: Equatable {
        case signInButtonTapped
        case responseReceived(Result<SignInState, AWSCognitoError>)
        case signOutButtonTapped
        case usernameChanged(String)
        case passwordChanged(String)
    }
    
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient

    var body: some ReducerOf<LoginFeature> {
        Reduce{ state, action in
            switch action {
        
            case .signInButtonTapped:
                return .run {[username = state.username, password = state.password] send in
                    let result = await awsCognitoClient.signIn(username, password)
                    await send(.responseReceived(result.map{ $0.signInState }))
                }
            case .responseReceived(.success(_)):
                state.errorMessage = nil
                return .run { send in
                    let result = await awsCognitoClient.getTokens()
                    switch result {
                    case .success(let tokens):
                        if let accessToken = tokens.accessToken?.tokenString {
                            await userDefaultsClient.setString(accessToken, "AccessToken")
                            print("Access Token: \(accessToken)")
                        } else {
                            print("No access token found")
                        }
                    case .failure(_):
                        return
                    }
                }
            case .responseReceived(.failure(let error)):
                print("responseReceived failure")
                print(error.localizedDescription)
                state.errorMessage = error.localizedDescription
                return .none
            case .signOutButtonTapped:
                return .run { send in
                    let _ = await awsCognitoClient.signOut()
                }
            case .usernameChanged(let newUsername):
                state.username = newUsername
                return .none
            case .passwordChanged(let newPassword):
                state.password = newPassword
                return .none
            }
        }
    }
}
