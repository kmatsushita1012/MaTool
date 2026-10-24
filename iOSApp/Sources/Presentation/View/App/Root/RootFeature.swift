import ComposableArchitecture
import Dependencies
import Shared

enum SceneSessionCancellationID {
    case active
}

@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        enum Scene: Equatable {
            case loading
            case home
            case onboarding
            case error(String)
        }

        @Shared fileprivate var appState: AppState?
        @Shared var launchState: LaunchState
        var status: StatusCheckResult?
        var didLaunch = false
        var home: HomeFeature.State?
        var onboarding: OnboardingFeature.State?

        var scene: Scene {
            switch launchState {
            case .district, .festival:
                .home
            case .onboarding:
                .onboarding
            case .loading:
                .loading
            case .error(let message):
                .error(message)
            }
        }

        var errorStatus: StatusCheckResult? {
            if case .error = launchState { status } else { nil }
        }

        var normalStatus: StatusCheckResult? {
            if case .error = launchState { nil } else { status }
        }

        init() {
            self._appState = Shared(value: nil)
            self._launchState = Shared(value: .loading)
        }

        func makeHomeState(userRole: UserRole, currentRouteId: Route.ID? = nil) -> HomeFeature.State {
            HomeFeature.State(userRole: userRole, currentRouteId: currentRouteId, appState: self.$appState)
        }

        func makeOnboardingState() -> OnboardingFeature.State {
            OnboardingFeature.State(launchState: self.$launchState, appState: self.$appState)
        }
    }

    @CasePathable
    enum Action: Equatable {
        case launch
        case launchFinished(LaunchState, StatusCheckResult?)
        case statusDismissed
        case home(HomeFeature.Action)
        case onboarding(OnboardingFeature.Action)
    }

    @Dependency(LaunchSceneUseCaseKey.self) private var launchSceneUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .launch:
                guard !state.didLaunch else { return .none }
                state.didLaunch = true
                state.home = nil
                state.onboarding = nil
                state.$launchState.withLock { $0 = .loading }
                return .run { [appState = state.$appState] send in
                    let (launchState, status) = await launchSceneUseCase(appState: appState)
                    await send(.launchFinished(launchState, status))
                }
                .cancellable(id: SceneSessionCancellationID.active, cancelInFlight: true)

            case .launchFinished(let launchState, let status):
                state.$launchState.withLock { $0 = launchState }
                state.status = status
                switch launchState {
                case .district(let userRole, let routeId):
                    state.home = state.makeHomeState(userRole: userRole, currentRouteId: routeId)
                    state.onboarding = nil
                    return .none
                case .festival(let userRole):
                    state.home = state.makeHomeState(userRole: userRole)
                    state.onboarding = nil
                    return .none
                case .onboarding:
                    state.home = nil
                    state.onboarding = state.makeOnboardingState()
                    return .send(.onboarding(.onAppear))
                case .loading, .error:
                    state.home = nil
                    state.onboarding = nil
                }
                return .none

            case .onboarding(.delegate(.continueAsGuest)):
                guard case .festival(let userRole) = state.launchState else { return .none }
                state.home = state.makeHomeState(userRole: userRole)
                state.onboarding = nil
                return .none

            case .onboarding(.delegate(.districtSelected(let routeId))):
                guard case .district(let userRole, _) = state.launchState else { return .none }
                state.home = state.makeHomeState(userRole: userRole, currentRouteId: routeId)
                state.onboarding = nil
                return .none

            case .statusDismissed:
                state.status = nil
                return .none

            case .home(.destination(.presented(.adminDistrict(.signOutReceived(.success(_)))))),
                 .home(.destination(.presented(.adminFestival(.signOutReceived(.success(_)))))),
                 .home(.destination(.presented(.settings(.signOutReceived(.success(_)))))):
                state.didLaunch = false
                state.$launchState.withLock { $0 = .loading }
                return .send(.launch)

            case .home, .onboarding:
                return .none
            }
        }
        .ifLet(\.home, action: \.home) { HomeFeature() }
        .ifLet(\.onboarding, action: \.onboarding) { OnboardingFeature() }
    }
}
