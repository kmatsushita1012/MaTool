//
//  AuthFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture

@Reducer
struct LoginFeature {
    @ObservableState
    struct State: Equatable {
        var id: String = ""
        var password: String = ""
        var errorMessage: String?
        @Presents var confirmSignIn: ConfirmSignInFeature.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case signInTapped
        case received(AWSCognito.SignInResult)
        case homeTapped
        case confirmSignIn(PresentationAction<ConfirmSignInFeature.Action>)
    }
    
    @Dependency(\.awsCognitoClient) var awsCognitoClient
    @Dependency(\.accessToken) var accessToken

    var body: some ReducerOf<LoginFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .signInTapped:
                return .run {[id = state.id, password = state.password] send in
                    let result = await awsCognitoClient.signIn(id, password)
                    await send(.received(result))
                }
            case .received(AWSCognito.SignInResult.success):
                state.errorMessage = nil
                
                return .run { send in
                    let result = await awsCognitoClient.getTokens()
                    switch result {
                    case .success(let tokens):
                        if let token = tokens.accessToken?.tokenString {
                            accessToken.value = token
                        } else {
                            print("No access token found")
                        }
                    case .failure(_):
                        return
                    }
                }
            case .received(AWSCognito.SignInResult.newPasswordRequired):
                state.confirmSignIn = ConfirmSignInFeature.State()
                return .none
            case .received(AWSCognito.SignInResult.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .homeTapped:
                return .none
            case .confirmSignIn(.presented(.received(.success))):
//                state.confirmSignIn = nil
                return .none
            case .confirmSignIn(.presented(.received(.failure))):
                state.confirmSignIn = nil
                return .none
            case .confirmSignIn(_):
                return .none
            }
        }
        .ifLet(\.$confirmSignIn, action: \.confirmSignIn){
            ConfirmSignInFeature()
        }
    }
}
