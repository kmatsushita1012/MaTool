//
//  AuthFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture

@Reducer
struct Login {
    
    @Reducer
    enum Destination {
        case confirmSignIn(ConfirmSignIn)
        case resetPassword(ResetPassword)
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
        case homeTapped
        case signInTapped
        case received(SignInResult)
        case resetPasswordTapped
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<Login> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .signInTapped:
                state.isLoading = true
                return .run {[id = state.id, password = state.password] send in
                    let result = await authService.signIn(id, password: password)
                    await send(.received(result))
                }
            case .homeTapped:
                return .run { _ in
                    await dismiss()
                }
            case .resetPasswordTapped:
                state.destination = .resetPassword(ResetPassword.State(username: state.id))
                return .none
            case .received(.success(let userRole)):
                state.errorMessage = nil
                switch userRole {
                case .headquarter(let id):
                    userDefaultsClient.setString(id, defaultFestivalKey)
                    userDefaultsClient.setString(nil, defaultDistrictKey)
                    userDefaultsClient.setString(id, loginIdKey)
                    return .none
                case .district(let id):
                    userDefaultsClient.setString(id, defaultDistrictKey)
                    userDefaultsClient.setString(id, loginIdKey)
                    return .none
                case .guest:
                    return .none
                }
            case .received(.newPasswordRequired):
                state.destination = .confirmSignIn(ConfirmSignIn.State())
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
            case .destination(.dismiss):
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension Login.Destination.State: Equatable {}
extension Login.Destination.Action: Equatable {}
