//
//  UpdateEmail.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import Shared

@Reducer
struct UpdateEmailFeature {
    
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var code: String = ""
        var step: Step = .enterEmail
        var isLoading: Bool = false
        @Presents var errorAlert: AlertFeature.State? = nil
        @Presents var completeAlert: AlertFeature.State? = nil
        
        enum Step: Equatable {
            case enterEmail
            case enterCode(destination: String)
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case enterEmail(NavigationAction)
        case enterCode(NavigationAction)
        
        @CasePathable
        enum NavigationAction: Equatable {
            case okTapped
            case dismissTapped
        }
        
        case resendTapped
        case updateReceived(TaskResult<UpdateEmailState>)
        case confirmUpdateReceived(VoidTaskResult)
        case errorAlert(PresentationAction<AlertFeature.Action>)
        case completeAlert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<UpdateEmailFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .enterEmail(.okTapped),
                .resendTapped:
                state.isLoading = true
                return .task(Action.updateReceived) { [email = state.email] in
                    try await authService.updateEmail(to: email)
                }
            case .enterCode(.okTapped):
                state.isLoading = true
                return .task(Action.confirmUpdateReceived) { [code = state.code] in
                    try await authService.confirmUpdateEmail(code: code)
                }
            case .enterEmail(.dismissTapped),
                .enterCode(.dismissTapped):
                return .dismiss
            case .updateReceived(.success(.completed)):
                state.isLoading = false
                state.completeAlert = AlertFeature.success("メールアドレスが変更されました")
                return .none
            case .updateReceived(.success(.verificationRequired(destination: let destination))):
                state.isLoading = false
                state.step = .enterCode(destination: destination)
                return .none
            case .updateReceived(.failure(let error)):
                state.isLoading = false
                state.errorAlert = .error(error.localizedDescription)
                return .none
            case .confirmUpdateReceived(.success):
                state.isLoading = false
                state.completeAlert = AlertFeature.success("メールアドレスが変更されました")
                return .none
            case .confirmUpdateReceived(.failure(let error)):
                state.isLoading = false
                state.errorAlert = .error(error.localizedDescription)
                return .none
            case .errorAlert:
                state.errorAlert = nil
                return .none
            case .completeAlert:
                state.completeAlert = nil
                return .dismiss
            }
        }
        .ifLet(\.$errorAlert, action: \.errorAlert)
        .ifLet(\.$completeAlert, action: \.completeAlert)
    }
}
