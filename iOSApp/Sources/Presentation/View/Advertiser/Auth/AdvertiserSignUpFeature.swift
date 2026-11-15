import ComposableArchitecture
import Foundation
import Shared

@Reducer
struct AdvertiserSignUpFeature {
    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var passwordConfirmation = ""
        var confirmationCode = ""
        var isAwaitingConfirmation = false
        var isLoading = false
        var errorMessage: String?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case signUpTapped
        case confirmationTapped
        case received(AppResult<AdvertiserAuthResult>)
    }

    @Dependency(\.advertiserAuthUsecase) private var advertiserAuthUsecase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.errorMessage = nil
                return .none

            case .signUpTapped:
                guard !state.isLoading else { return .none }
                guard !state.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    state.errorMessage = "メールアドレスを入力してください。"
                    return .none
                }
                guard !state.password.isEmpty else {
                    state.errorMessage = "パスワードを入力してください。"
                    return .none
                }
                guard !state.passwordConfirmation.isEmpty else {
                    state.errorMessage = "パスワード（確認用）を入力してください。"
                    return .none
                }
                guard state.password == state.passwordConfirmation else {
                    state.errorMessage = "パスワードが一致しません"
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let email = state.email
                let password = state.password
                return .task(Action.received) {
                    switch try await advertiserAuthUsecase.signUp(email: email, password: password) {
                    case .confirmationRequired:
                        .confirmationRequired
                    case .signedIn(let role):
                        .signedIn(role)
                    }
                }

            case .confirmationTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let email = state.email
                let password = state.password
                let code = state.confirmationCode
                return .task(Action.received) {
                    .signedIn(try await advertiserAuthUsecase.confirmSignUp(
                        email: email,
                        password: password,
                        code: code
                    ))
                }

            case .received(.success(.confirmationRequired)):
                state.isLoading = false
                state.isAwaitingConfirmation = true
                state.passwordConfirmation = ""
                return .none

            case .received(.success(.signedIn)):
                state.isLoading = false
                return .none

            case .received(.failure(let error)):
                state.isLoading = false
                let message = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
                state.errorMessage = message.isEmpty
                    ? "アカウントを作成できませんでした。入力内容を確認してください。"
                    : message
                return .none
            }
        }
    }
}
