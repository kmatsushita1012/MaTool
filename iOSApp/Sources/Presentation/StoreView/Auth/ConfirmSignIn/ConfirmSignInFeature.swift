//
//  ConfirmSignIn.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/21.
//

import ComposableArchitecture
import Shared

@Reducer
struct ConfirmSignInFeature {
    
    @ObservableState
    struct State: Equatable {
        var password1: String = ""
        var password2: String = ""
        var isLoading: Bool = false
        @Presents var alert: AlertFeature.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case dismissTapped
        case received(TaskResult<UserRole>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.authService) var authService
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.loginIdKey) var loginIdKey
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<ConfirmSignInFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                if state.password1 != state.password2 {
                    state.alert = AlertFeature.error("パスワードが一致しません。")
                    return .none
                } else if !authService.isValidPassword(state.password1) {
                    state.alert = AlertFeature.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .task(Action.received) { [password = state.password1] in
                    try await authService.confirmSignIn(password: password)
                }
            case .dismissTapped:
                return .dismiss
            case .received(.success(let userRole)):
                switch userRole {
                case .headquarter(let id):
                    return .none
                case .district(let id):
                    return .none
                case .guest:
                    return .none
                }
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFeature.error("送信に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
