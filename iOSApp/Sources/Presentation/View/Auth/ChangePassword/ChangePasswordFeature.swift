//
//  ChangePassword.swift
//  MaTool
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture
import Shared

@Reducer
struct ChangePasswordFeature {
    
    @ObservableState
    struct State: Equatable {
        var current: String = ""
        var new1: String = ""
        var new2: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case okTapped
        case dismissTapped
        case received(VoidTaskResult)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<ChangePasswordFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .okTapped:
                if state.new1 != state.new2 {
                    state.alert = AlertFeature.error("パスワード（確認用）が一致しません")
                    return .none
                } else if !authService.isValidPassword(state.new1) {
                    state.alert =  AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .task(Action.received) { [current = state.current, new = state.new1] in
                    try await authService.changePassword(current: current, new: new)
                }
            case .dismissTapped:
                return .dismiss
            case .received(.success):
                state.isLoading = false
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("変更に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
