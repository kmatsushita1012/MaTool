//
//  UpdateEmail.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import Shared

@Reducer
struct UpdateEmail {
    
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var code: String = ""
        var step: Step = .enterEmail
        var isLoading: Bool = false
        @Presents var errorAlert: Alert.State? = nil
        @Presents var completeAlert: Alert.State? = nil
        
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
        case updateReceived(UpdateEmailResult)
        case confirmUpdateReceived(Result<Empty, AuthError>)
        case errorAlert(PresentationAction<Alert.Action>)
        case completeAlert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<UpdateEmail> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .enterEmail(.okTapped),
                .resendTapped:
                state.isLoading = true
                return .run { [email = state.email] send in
                    let result = await authService.updateEmail(to: email)
                    await send(.updateReceived(result))
                }
            case .enterCode(.okTapped):
                state.isLoading = true
                return .run { [code = state.code] send in
                    let result = await authService.confirmUpdateEmail(code: code)
                    await send(.confirmUpdateReceived(result))
                }
            case .enterEmail(.dismissTapped),
                .enterCode(.dismissTapped):
                return .run { _ in
                    await dismiss()
                }
            case .updateReceived(.completed):
                state.isLoading = false
                state.completeAlert = Alert.success("メールアドレスが変更されました")
                return .none
            case .updateReceived(.verificationRequired(destination: let destination)):
                state.isLoading = false
                state.step = .enterCode(destination: destination)
                return .none
            case .updateReceived(.failure(let error)):
                state.isLoading = false
                state.errorAlert = Alert.error("変更に失敗しました　\(error.localizedDescription)")
                return .none
            case .confirmUpdateReceived(.success):
                state.isLoading = false
                state.completeAlert = Alert.success("メールアドレスが変更されました")
                return .none
            case .confirmUpdateReceived(.failure(let error)):
                state.isLoading = false
                state.errorAlert = Alert.error("変更に失敗しました　\(error.localizedDescription)")
                return .none
            case .errorAlert:
                state.errorAlert = nil
                return .none
            case .completeAlert:
                state.completeAlert = nil
                return .run { _ in
                    await dismiss()
                }
            }
        }
        .ifLet(\.$errorAlert, action: \.errorAlert)
        .ifLet(\.$completeAlert, action: \.completeAlert)
    }
}
