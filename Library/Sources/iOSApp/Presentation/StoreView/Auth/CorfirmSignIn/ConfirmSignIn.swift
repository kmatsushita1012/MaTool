//
//  ConfirmSignIn.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/21.
//

import ComposableArchitecture

@Reducer
struct ConfirmSignIn {
    
    @ObservableState
    struct State: Equatable {
        var password1: String = ""
        var password2: String = ""
        var isLoading: Bool = false
        @Presents var alert: Alert.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case dismissTapped
        case received(Result<UserRole, AuthError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<ConfirmSignIn> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                if state.password1 != state.password2 {
                    state.alert = Alert.error("パスワードが一致しません。")
                    return .none
                } else if !authService.isValidPassword(state.password1) {
                    state.alert = Alert.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .run { [password = state.password1] send in
                    let result = await authService.confirmSignIn(password: password)
                    await send(.received(result))
                }
            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
            case .received(.success(let userRole)):
                switch userRole {
                case .region(let id):
                    userDefaultsClient.setString(id, defaultRegionKey)
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
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("送信に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
