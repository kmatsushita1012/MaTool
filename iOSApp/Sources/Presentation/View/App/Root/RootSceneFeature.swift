import ComposableArchitecture
import Dependencies
import Shared
import SQLiteData

@Reducer
struct RootSceneFeature {
    @ObservableState
    struct State: Equatable {
        @Shared var launchState: LaunchState
        var status: StatusCheckResult?
        var home: HomeFeature.State?
        var hasStarted = false

        init(launchState: Shared<LaunchState>) {
            self._launchState = launchState
        }
    }

    @CasePathable
    enum Action: Equatable {
        case start
        case launchFinished(LaunchState, StatusCheckResult?)
        case launchStateChanged
        case statusDismissed
        case home(HomeFeature.Action)
    }

    @Dependency(SceneUsecaseKey.self) var sceneUsecase
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.values.defaultFestivalKey) var defaultFestivalKey
    @Dependency(\.values.defaultDistrictKey) var defaultDistrictKey
    @Dependency(\.values.publicTabLinkingKey) var publicTabLinkingKey

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                guard !state.hasStarted else { return .none }
                state.hasStarted = true
                return .run { send in
                    let (launchState, status) = await sceneUsecase.launch()
                    await send(.launchFinished(launchState, status))
                }

            case .launchFinished(let launchState, let status):
                state.status = status
                state.$launchState.withLock { $0 = launchState }
                return configureHome(state: &state)

            case .launchStateChanged:
                guard state.home == nil else { return .none }
                return configureHome(state: &state)

            case .statusDismissed:
                state.status = nil
                return .none

            case .home:
                return .none
            }
        }
        .ifLet(\.home, action: \.home) {
            HomeFeature()
        }
    }

    private func configureHome(state: inout State) -> Effect<Action> {
        switch state.launchState {
        case .festival(let userRole):
            guard let home = makeHomeState(userRole: userRole, routeID: nil) else {
                state.home = nil
                state.$launchState.withLock {
                    $0 = .error("選択中の祭典を読み込めませんでした。")
                }
                return .none
            }
            state.home = home
            return .send(.home(.initialize))

        case .district(let userRole, let routeID):
            guard let home = makeHomeState(userRole: userRole, routeID: routeID) else {
                state.home = nil
                state.$launchState.withLock {
                    $0 = .error("選択中の祭典を読み込めませんでした。")
                }
                return .none
            }
            state.home = home
            return .send(.home(.initialize))

        case .onboarding, .loading, .error:
            state.home = nil
            return .none
        }
    }

    private func makeHomeState(
        userRole: UserRole,
        routeID: Route.ID?
    ) -> HomeFeature.State? {
        guard let festivalID = userDefaultsClient.string(defaultFestivalKey),
              let festival = FetchOne(Festival.find(festivalID)).wrappedValue else {
            return nil
        }

        let districtID = userDefaultsClient.string(defaultDistrictKey)
        let district = districtID.flatMap {
            FetchOne(District.find($0)).wrappedValue
        }
        let isLinked = userDefaultsClient.contains(publicTabLinkingKey)
            ? userDefaultsClient.bool(publicTabLinkingKey)
            : true

        return HomeFeature.State(
            userRole: userRole,
            festival: festival,
            district: district,
            routeID: routeID,
            isPublicSelectionLinked: isLinked
        )
    }
}
