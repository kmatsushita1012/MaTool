//
//  ResetPasswordFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import Shared

@Reducer
struct ResetPasswordFeature {
    
    @ObservableState
    struct State: Equatable {
        var username: String = ""
        var newPassword1: String = ""
        var newPassword2: String = ""
        var code: String = ""
        var isLoading: Bool = false
        var step: Step = .enterUsername
        
        enum Step: Equatable {
            case enterUsername
            case enterCode
        }
        
        @Presents var alert: AlertFeature.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case enterUsername(NavigationAction)
        case enterCode(NavigationAction)
        case resetReceived(VoidTaskResult)
        case confirmResetReceived(VoidTaskResult)
        case resendTapped
        case alert(PresentationAction<AlertFeature.Action>)
        
        @CasePathable
        enum NavigationAction: Equatable {
            case okTapped
            case dismissTapped
        }
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<ResetPasswordFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action{
            case .binding:
                return .none
            case .enterUsername(.okTapped),
                .resendTapped:
                return .task(Action.resetReceived) { [username = state.username] in
                    try await authService.resetPassword(username: username)
                }
            case .enterCode(.okTapped):
                if state.newPassword1 != state.newPassword2 {
                    state.alert = AlertFeature.error("パスワード（確認用）が一致しません")
                    return .none
                } else if !authService.isValidPassword(state.newPassword1) {
                    state.alert =  AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .task(Action.confirmResetReceived) {
                    [
                        username = state.username,
                        password = state.newPassword1,
                        code = state.code
                    ] in
                    try await authService.confirmResetPassword(
                        username: username,
                        newPassword: password,
                        code: code
                    )
                }
            case .enterUsername(.dismissTapped),
                .enterCode(.dismissTapped):
                return .dismiss
            case .resetReceived(.success):
                state.isLoading = false
                state.step = .enterCode
                return .none
            case .resetReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("リセットに失敗しました。\(error.localizedDescription)")
                return .none
            case .confirmResetReceived(.success):
                state.isLoading = false
                return .none
            case .confirmResetReceived(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("リセットに失敗しました。\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
