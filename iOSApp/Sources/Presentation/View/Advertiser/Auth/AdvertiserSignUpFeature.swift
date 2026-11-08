import ComposableArchitecture
import Shared

@Reducer
struct AdvertiserSignUpFeature {
    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
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
                return .none

            case .received(.success(.signedIn)):
                state.isLoading = false
                return .none

            case .received(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none
            }
        }
    }
}
