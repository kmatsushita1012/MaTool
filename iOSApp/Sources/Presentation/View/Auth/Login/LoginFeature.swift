//
//  LoginFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/03/20.
//

import Foundation
import ComposableArchitecture
import OSLog
import Shared

private let loginLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MaTool", category: "LoginFeature")

private enum LoginCancellationID {
    case signIn
}

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
        @Shared fileprivate var appState: AppState?
        @Presents var destination: Destination.State?

        init(id: String = "", appState: Shared<AppState?> = Shared(value: nil)) {
            self.id = id
            self._appState = appState
        }
    }
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case dismissTapped
        case signInTapped
        case received(AppResult<SignInState>)
        case resetPasswordTapped
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(SignInUseCaseKey.self) var signInUseCase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<LoginFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .signInTapped:
                guard !state.isLoading else { return .none }
                loginLogger.info("signInTapped: starting sign-in effect")
                state.isLoading = true
                return .task(Action.received) { [id = state.id, password = state.password, appState = state.$appState] in
                    try await signInUseCase(username: id, password: password, appState: appState)
                }
                .cancellable(id: LoginCancellationID.signIn, cancelInFlight: true)
            case .dismissTapped:
                return .dismiss
            case .resetPasswordTapped:
                state.destination = .resetPassword(ResetPasswordFeature.State(username: state.id))
                return .none
            case .received(.success(.newPasswordRequired)):
                loginLogger.info("received: new password required")
                state.destination = .confirmSignIn(ConfirmSignInFeature.State(appState: state.$appState))
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case .received(.success(.signedIn(_))):
                loginLogger.info("received: sign-in succeeded")
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case .received(.failure(let error)):
                loginLogger.error("received: sign-in failed (\(String(reflecting: type(of: error)), privacy: .public))")
                state.isLoading = false
                state.errorMessage = error.message
                return .none
            case .destination(.presented(.resetPassword(.confirmResetReceived(.success)))):
                state.destination = nil
                return .none
            case .destination(.presented(.confirmSignIn(.received(.success(_))))):
                state.destination = nil
                state.isLoading = false
                state.errorMessage = nil
                return .none
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension LoginFeature.Destination.State: Equatable {}
extension LoginFeature.Destination.Action: Equatable {}
