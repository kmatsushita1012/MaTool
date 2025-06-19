//
//  ConfirmSignIn.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/21.
//

import ComposableArchitecture

@Reducer
struct ConfirmSignIn {
    @Dependency(\.authProvider) var authProvider
    
    @ObservableState
    struct State: Equatable {
        var password1: String = ""
        var password2: String = ""
        var isLoading: Bool = false
        @Presents var alert: OkAlert.State? = nil
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case submitTapped
        case dismissTapped
        case received(Result<Empty, AuthError>)
        case alert(PresentationAction<OkAlert.Action>)
    }
    
    var body: some ReducerOf<ConfirmSignIn> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .submitTapped:
                if state.password1 != state.password2 {
                    state.alert = OkAlert.error("パスワードが一致しません。")
                    return .none
                }else if !isValidPassword(state.password1) {
                    state.alert = OkAlert.error("パスワードが条件を満たしていません。次の条件を満たしてください。\n 8文字以上 \n 少なくとも 1 つの数字を含む \n 少なくとも 1 つの大文字を含む \n 少なくとも 1 つの小文字を含む")
                    return .none
                }
                state.isLoading = true
                return .run { [ password1 = state.password1 ]send in
                    let result = await authProvider.confirmSignIn(password1)
                    await send(.received(result))
                }
            case .dismissTapped:
                return .none
            case .received(.success):
                state.isLoading = false
                return .none
            case .received(.failure(let error)):
                state.isLoading = false
                state.alert = OkAlert.error("送信に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none
            case .alert:
                return .none
            }
            
        }
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        let lengthRule = password.count >= 8
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil

        return lengthRule && hasNumber && hasUppercase && hasLowercase
    }

}
