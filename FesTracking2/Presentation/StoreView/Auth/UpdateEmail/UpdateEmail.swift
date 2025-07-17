//
//  UpdateEmail.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/17.
//

import ComposableArchitecture

@Reducer
struct UpdateEmail {
    
    @Dependency(\.authService) var authService
    
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var code: String = ""
        var step: Step = .enterEmail
        var isLoading: Bool = false
        @Presents var alert: Alert.State? = nil
        
        enum Step: Equatable {
            case enterEmail
            case enterCode
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
        case updateReceived(Result<Empty, AuthError>)
        case confirmUpdateReceived(Result<Empty, AuthError>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    var body: some ReducerOf<UpdateEmail> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .enterEmail(.okTapped),
                .resendTapped:
                state.isLoading = true
                state.alert = Alert.success("入力したメールアドレスに6桁の確認コードを送信しました。次の画面で入力してください。")
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
                return .none
            case .updateReceived(.success):
                state.isLoading = false
                state.step = .enterCode
                return .none
            case .updateReceived(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("変更に失敗しました。\(error.localizedDescription)")
                return .none
            case .confirmUpdateReceived(.success):
                state.isLoading = false
                return .none
            case .confirmUpdateReceived(.failure(let error)):
                state.isLoading = false
                state.alert = Alert.error("変更に失敗しました。\(error.localizedDescription)")
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
