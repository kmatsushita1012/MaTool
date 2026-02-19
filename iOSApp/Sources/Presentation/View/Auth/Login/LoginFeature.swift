//
//  AuthFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture

@Reducer
struct LoginFeature {
    
    @Reducer
    enum Destination {
        case confirmSignIn(ConfirmSignInFeature)
        case resetPassword(ResetPasswordFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var id: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String? = nil
        @Presents var destination: Destination.State?
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signInTapped
        case received(TaskResult<SignInState>)
        case resetPasswordTapped
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<LoginFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .signInTapped:
                state.isLoading = true
                return .task(Action.received) { [state] in
                    try await sceneUsecase.signIn(username: state.id, password: state.password)
                }
            case .dismissTapped:
                return .dismiss
            case .resetPasswordTapped:
                state.destination = .resetPassword(ResetPasswordFeature.State(username: state.id))
                return .none
            case .received(.success(.newPasswordRequired)):
                state.destination = .confirmSignIn(ConfirmSignInFeature.State())
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .destination(.presented(let childAction)):
                switch childAction {
                case .resetPassword(.confirmResetReceived(.success)):
                    state.destination = nil
                    return .none
                case .confirmSignIn,
                    .resetPassword:
                    return .none
                }
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension LoginFeature.Destination.State: Equatable {}
extension LoginFeature.Destination.Action: Equatable {}
