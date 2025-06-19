//
//  AuthFeature.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture

@Reducer
struct Login {
    
    @Dependency(\.authProvider) var authProvider
    @Dependency(\.accessToken) var accessToken
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    @ObservableState
    struct State: Equatable {
        var id: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String? = nil
        @Presents var confirmSignIn: ConfirmSignIn.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case signInTapped
        case received(AuthSignInResult)
        case homeTapped
        case confirmSignIn(PresentationAction<ConfirmSignIn.Action>)
    }
    
    var body: some ReducerOf<Login> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .signInTapped:
                state.isLoading = true
                return .run {[id = state.id, password = state.password] send in
                    let result = await authProvider.signIn(id, password)
                    await send(.received(result))
                }
            case .received(.success):
                state.errorMessage = nil
                return .none
            case .received(.newPasswordRequired):
                state.confirmSignIn = ConfirmSignIn.State()
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.errorMessage = "ログインに失敗しました。\(error.localizedDescription)"
                return .run { send in
                    let result = await authProvider.signOut()
                    print(result)
                }
            case .homeTapped:
                return .none
            case .confirmSignIn(.presented(.received(.success))):
                return .none
            case .confirmSignIn(.presented(.received(.failure))):
                state.confirmSignIn = nil
                return .none
            case .confirmSignIn(_):
                return .none
            }
        }
        .ifLet(\.$confirmSignIn, action: \.confirmSignIn){
            ConfirmSignIn()
        }
    }
}
