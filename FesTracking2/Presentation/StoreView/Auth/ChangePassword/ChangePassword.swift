//
//  ChangePassword.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture

@Reducer
struct ChangePassword {
    
    @Dependency(\.authService) var authService
    
    @ObservableState
    struct State: Equatable {
        var current: String = ""
        var new1: String = ""
        var new2: String = ""
        var isLoading: Bool
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case okTapped
        case dismissTapped
        case received(Result<Empty, AuthError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<ChangePassword> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .okTapped:
                if state.new1 != state.new2 {
                    state.alert = Alert.error("パスワード（確認用）が一致しません")
                    return .none
                } else if !authService.isValidPassword(state.new1) {
                    state.alert =  Alert.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .run { [current = state.current, new = state.new1] send in
                    let result = await authService.changePassword(current: current, new: new)
                    await send(.received(result))
                }
            case .dismissTapped:
                return .none
            case .received(.success):
                state.isLoading = false
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("変更に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert(_):
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
