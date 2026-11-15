import ComposableArchitecture
import Shared

@Reducer
struct AdvertiserAuthFeature {
    @Reducer
    enum Destination {
        case signUp(AdvertiserSignUpFeature)
        case resetPassword(ResetPasswordFeature)
    }

    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var isLoading = false
        var errorMessage: String?
        @Presents var destination: Destination.State?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case signInTapped
        case signUpTapped
        case resetPasswordTapped
        case received(AppResult<UserRole>)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.advertiserAuthUsecase) private var advertiserAuthUsecase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.errorMessage = nil
                return .none

            case .signInTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let email = state.email
                let password = state.password
                return .task(Action.received) {
                    try await advertiserAuthUsecase.signIn(email: email, password: password)
                }

            case .signUpTapped:
                state.destination = .signUp(AdvertiserSignUpFeature.State())
                return .none

            case .resetPasswordTapped:
                state.destination = .resetPassword(ResetPasswordFeature.State(username: state.email))
                return .none

            case .received(.success):
                state.isLoading = false
                state.errorMessage = nil
                return .none

            case .received(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.message
                return .none

            case .destination(.presented(.resetPassword(.confirmResetReceived(.success)))):
                state.destination = nil
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

enum AdvertiserAuthResult: Equatable {
    case confirmationRequired
    case signedIn(UserRole)
}

extension AdvertiserAuthFeature.Destination.State: Equatable {}
extension AdvertiserAuthFeature.Destination.Action: Equatable {}
