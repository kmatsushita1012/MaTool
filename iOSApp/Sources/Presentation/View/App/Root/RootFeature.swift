import ComposableArchitecture
import Dependencies
import OSLog
import Shared

private let rootFeatureLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MaTool", category: "RootFeature")

enum SceneSessionCancellationID {
    case active
}

@Reducer
struct RootFeature {
    @Reducer
    enum Destination {
        case settings(SettingsFeature)
        case adminDistrict(DistrictDashboardFeature)
        case adminFestival(FestivalDashboardFeature)
    }

    @Reducer
    enum Sheet {
        case festival(FestivalInfoFeature)
        case district(DistrictIntroductionRootFeature)
    }

    @ObservableState
    struct State: Equatable {
        enum Scene: Equatable {
            case loading
            case map
            case onboarding
            case error(String)
        }

        @Shared fileprivate var appState: AppState?
        @Shared var launchState: LaunchState
        var status: StatusCheckResult?
        var didLaunch = false
        var map: PublicMapFeature.State?
        var onboarding: OnboardingFeature.State?
        @Presents var destination: Destination.State?
        @Presents var sheet: Sheet.State?
        @Presents var alert: AlertFeature.State?
        var isDestinationLoading = false
        var isIntroductionLoading = false

        var scene: Scene {
            switch launchState {
            case .district, .festival:
                .map
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

        init(appState: Shared<AppState?>) {
            self._appState = appState
            self._launchState = Shared(value: .loading)
        }

        func makeMapState(userRole: UserRole, currentRouteId: Route.ID? = nil) -> PublicMapFeature.State? {
            guard let festival = appState?.festivalState.festival else { return nil }
            if let district = appState?.selectedDistrict {
                return PublicMapFeature.State(
                    festival: festival,
                    district: district,
                    routeId: currentRouteId,
                    userRole: userRole,
                    appState: self.$appState
                )
            }
            return PublicMapFeature.State(
                festival: festival,
                userRole: userRole,
                appState: self.$appState
            )
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
        case map(PublicMapFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        case sheet(PresentationAction<Sheet.Action>)
        case settingsPrepared(AppResult<SettingsPreparation>)
        case introductionPrepared(AppResult<IntroSheetPreparation>)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(LaunchSceneUseCaseKey.self) private var launchSceneUseCase
    @Dependency(FetchFestivalListUseCaseKey.self) private var fetchFestivalListUseCase
    @Dependency(FetchDistrictUseCaseKey.self) private var fetchDistrictUseCase
    @Dependency(GetSceneSelectionUseCaseKey.self) private var getSceneSelectionUseCase
    @Dependency(LastMainScreenUseCaseKey.self) private var lastMainScreenUseCase
    @Dependency(\.imageCacheClient) private var imageCacheClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .launch:
                guard !state.didLaunch else { return .none }
                state.didLaunch = true
                state.map = nil
                state.onboarding = nil
                state.destination = nil
                state.sheet = nil
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
                    state.map = state.makeMapState(userRole: userRole, currentRouteId: routeId)
                    state.onboarding = nil
                    if userRole == .guest {
                        lastMainScreenUseCase.save(nil)
                        state.destination = nil
                    } else if lastMainScreenUseCase.load() == .admin {
                        guard setAdminDestination(state: &state, userRole: userRole) else {
                            lastMainScreenUseCase.save(.map)
                            return .none
                        }
                    } else {
                        lastMainScreenUseCase.save(.map)
                        state.destination = nil
                    }
                    return .none
                case .festival(let userRole):
                    state.map = state.makeMapState(userRole: userRole)
                    state.onboarding = nil
                    if userRole == .guest {
                        lastMainScreenUseCase.save(nil)
                        state.destination = nil
                    } else if lastMainScreenUseCase.load() == .admin {
                        guard setAdminDestination(state: &state, userRole: userRole) else {
                            lastMainScreenUseCase.save(.map)
                            return .none
                        }
                    } else {
                        lastMainScreenUseCase.save(.map)
                        state.destination = nil
                    }
                    return .none
                case .onboarding:
                    state.map = nil
                    state.destination = nil
                    state.onboarding = state.makeOnboardingState()
                    return .send(.onboarding(.onAppear))
                case .loading, .error:
                    state.map = nil
                    state.destination = nil
                    state.onboarding = nil
                    return .none
                }

            case .map(.delegate(.settingsOrAdminTapped)):
                guard !state.isDestinationLoading && !state.isIntroductionLoading else { return .none }
                guard let userRole = currentUserRole(state.launchState) else { return .none }
                if userRole == .guest {
                    state.isDestinationLoading = true
                    return .task(Action.settingsPrepared) {
                        let festivals = try await fetchFestivalListUseCase()
                        let selection = getSceneSelectionUseCase()
                        return SettingsPreparation(festivals: festivals, selection: selection)
                    }
                }
                guard setAdminDestination(state: &state, userRole: userRole) else { return .none }
                lastMainScreenUseCase.save(.admin)
                return .none

            case .map(.delegate(.introductionTapped)):
                guard !state.isDestinationLoading && !state.isIntroductionLoading else { return .none }
                guard let festival = state.appState?.festivalState.festival,
                      let map = state.map else { return .none }
                let initialDistrictID: District.ID?
                switch map.selectedContent {
                case .locations:
                    initialDistrictID = nil
                case .route(let districtId):
                    initialDistrictID = districtId
                }
                return prepareIntroduction(state: &state, festival: festival, districtId: initialDistrictID)

            case .map(.destination(.presented(.locations(.floatTapped(let entry))))):
                guard let festival = state.appState?.festivalState.festival else { return .none }
                return prepareIntroduction(
                    state: &state,
                    festival: festival,
                    districtId: entry.district.id,
                    locationTimestamp: entry.floatLocation.timestamp
                )

            case .map(.destination(.presented(.route(.locationTapped(let entry))))):
                guard let festival = state.appState?.festivalState.festival else { return .none }
                return prepareIntroduction(
                    state: &state,
                    festival: festival,
                    districtId: entry.district.id,
                    locationTimestamp: entry.floatLocation.timestamp
                )

            case .map:
                return .none

            case .settingsPrepared(.success(let preparation)):
                state.isDestinationLoading = false
                guard let userRole = currentUserRole(state.launchState) else { return .none }
                state.destination = .settings(SettingsFeature.State(
                    selection: preparation.selection,
                    festivals: preparation.festivals,
                    userRole: userRole,
                    appState: state.$appState
                ))
                return .none

            case .settingsPrepared(.failure(let error)):
                state.isDestinationLoading = false
                state.alert = .error("設定画面の準備に失敗しました。\n\(error.message)")
                return .none

            case .introductionPrepared(.success(let preparation)):
                state.isIntroductionLoading = false
                switch preparation {
                case .festival(let festival):
                    state.sheet = .festival(FestivalInfoFeature.State(
                        festival,
                        appState: state.$appState
                    ))
                case .district(let festival, let pack, let locationTimestamp):
                    state.sheet = .district(DistrictIntroductionRootFeature.State(
                        pack,
                        festival: festival,
                        locationTimestamp: locationTimestamp,
                        appState: state.$appState
                    ))
                }
                return .none

            case .introductionPrepared(.failure(let error)):
                state.isIntroductionLoading = false
                state.alert = .error(error.message)
                return .none

            case .destination(.presented(.settings(.signOutReceived(.success)))),
                 .destination(.presented(.adminDistrict(.signOutReceived(.success)))),
                 .destination(.presented(.adminFestival(.signOutReceived(.success)))),
                 .destination(.presented(.adminDistrict(.destination(.presented(.settings(.signOutReceived(.success))))))),
                 .destination(.presented(.adminFestival(.destination(.presented(.settings(.signOutReceived(.success))))))):
                finishSignOut(state: &state)
                return .none

            case .destination(.presented(.settings(.delegate(.sceneSelectionChanged(let userRole, let routeId))))),
                 .destination(.presented(.adminDistrict(.destination(.presented(.settings(.delegate(.sceneSelectionChanged(let userRole, let routeId)))))))),
                 .destination(.presented(.adminFestival(.destination(.presented(.settings(.delegate(.sceneSelectionChanged(let userRole, let routeId)))))))):
                updateMapForSceneSelection(state: &state, userRole: userRole, currentRouteId: routeId)
                return .none

            case .destination(.presented(.settings(.delegate(.participationChanged(let preparation))))),
                 .destination(.presented(.adminDistrict(.destination(.presented(.settings(.delegate(.participationChanged(let preparation)))))))),
                 .destination(.presented(.adminFestival(.destination(.presented(.settings(.delegate(.participationChanged(let preparation)))))))):
                let routeId = state.appState?.routeState?.route.id
                updateMapForSceneSelection(state: &state, userRole: .guest, currentRouteId: routeId)
                state.destination = .settings(SettingsFeature.State(
                    selection: preparation.selection,
                    festivals: preparation.festivals,
                    userRole: .guest,
                    appState: state.$appState
                ))
                return .none

            case .destination(.presented(.settings(let settingsAction))),
                 .destination(.presented(.adminDistrict(.destination(.presented(.settings(let settingsAction)))))),
                 .destination(.presented(.adminFestival(.destination(.presented(.settings(let settingsAction)))))):
                switch settingsAction {
                case .destination(.presented(.login(.received(.success(.signedIn(let userRole)))))),
                     .destination(.presented(.login(.destination(.presented(.confirmSignIn(.received(.success(let userRole)))))))):
                    rootFeatureLogger.info("login success action reached RootFeature")
                    guard activateAdminSession(state: &state, userRole: userRole) else {
                        rootFeatureLogger.error("admin destination activation failed")
                        lastMainScreenUseCase.save(.map)
                        return .none
                    }
                    rootFeatureLogger.info("admin destination activated")
                    lastMainScreenUseCase.save(.admin)
                    return .none
                default:
                    return .none
                }

            case .destination(.dismiss):
                if let userRole = currentUserRole(state.launchState), userRole != .guest {
                    lastMainScreenUseCase.save(.map)
                }
                return .none

            case .destination:
                return .none

            case .sheet:
                return .none

            case .onboarding(.delegate(.continueAsGuest)):
                guard case .festival(let userRole) = state.launchState else { return .none }
                state.map = state.makeMapState(userRole: userRole)
                state.onboarding = nil
                return .none

            case .onboarding(.delegate(.districtSelected(let routeId))):
                guard case .district(let userRole, _) = state.launchState else { return .none }
                state.map = state.makeMapState(userRole: userRole, currentRouteId: routeId)
                state.onboarding = nil
                return .none

            case .onboarding:
                return .none

            case .statusDismissed:
                state.status = nil
                return .none

            case .alert(.presented(.okTapped)):
                state.alert = nil
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.map, action: \.map) { PublicMapFeature() }
        .ifLet(\.onboarding, action: \.onboarding) { OnboardingFeature() }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$sheet, action: \.sheet)
        .ifLet(\.$alert, action: \.alert)
    }

    private func currentUserRole(_ launchState: LaunchState) -> UserRole? {
        switch launchState {
        case .district(let userRole, _), .festival(let userRole):
            userRole
        case .onboarding, .loading, .error:
            nil
        }
    }

    private func prepareIntroduction(
        state: inout State,
        festival: Festival,
        districtId: District.ID?,
        locationTimestamp: Date? = nil
    ) -> Effect<Action> {
        guard !state.isIntroductionLoading else { return .none }
        state.isIntroductionLoading = true
        let fetchDistrictUseCase = self.fetchDistrictUseCase
        let imageCacheClient = self.imageCacheClient

        return .run { send in
            do {
                if let districtId {
                    let pack = try await fetchDistrictUseCase(districtId: districtId)
                    await imageCacheClient.preload(paths: [
                        pack.district.image.light,
                        pack.district.image.dark
                    ])
                    await send(.introductionPrepared(.success(.district(festival, pack, locationTimestamp))))
                } else {
                    await imageCacheClient.preload(paths: [festival.image.light, festival.image.dark])
                    await send(.introductionPrepared(.success(.festival(festival))))
                }
            } catch {
                await send(.introductionPrepared(.failure(error.asAppError)))
            }
        }
    }

    @discardableResult
    private func setAdminDestination(state: inout State, userRole: UserRole) -> Bool {
        switch userRole {
        case .headquarter(let festivalId):
            guard let festival = state.appState?.festivalState.festival,
                  festival.id == festivalId else {
                state.alert = .error("情報の取得に失敗しました")
                return false
            }
            state.destination = .adminFestival(.init(festival, appState: state.$appState))
            return true
        case .district(let districtId):
            guard let district = state.appState?.district(id: districtId) else {
                state.alert = .error("情報の取得に失敗しました")
                return false
            }
            state.destination = .adminDistrict(.init(district, appState: state.$appState))
            return true
        case .guest:
            return false
        }
    }

    @discardableResult
    private func activateAdminSession(state: inout State, userRole: UserRole) -> Bool {
        let currentRouteId = state.appState?.routeState?.route.id
        switch userRole {
        case .headquarter:
            state.$launchState.withLock { $0 = .festival(userRole) }
        case .district:
            state.$launchState.withLock { $0 = .district(userRole, currentRouteId) }
        case .guest:
            state.alert = .error("管理者としてログインできませんでした")
            return false
        }
        state.map = state.makeMapState(userRole: userRole, currentRouteId: currentRouteId)
        return setAdminDestination(state: &state, userRole: userRole)
    }

    private func updateMapForSceneSelection(
        state: inout State,
        userRole: UserRole,
        currentRouteId: Route.ID?
    ) {
        let previousRole = currentUserRole(state.launchState)
        guard let festival = state.appState?.festivalState.festival else { return }
        if let district = state.appState?.selectedDistrict {
            state.$launchState.withLock { $0 = .district(userRole, currentRouteId) }
            state.map = PublicMapFeature.State(
                festival: festival,
                district: district,
                routeId: currentRouteId,
                userRole: userRole,
                appState: state.$appState
            )
        } else {
            state.$launchState.withLock { $0 = .festival(userRole) }
            state.map = PublicMapFeature.State(
                festival: festival,
                userRole: userRole,
                appState: state.$appState
            )
        }

        if previousRole != .guest, userRole == .guest {
            state.destination = nil
            lastMainScreenUseCase.save(nil)
        }
    }

    private func finishSignOut(state: inout State) {
        let currentRouteId = state.appState?.routeState?.route.id
        let hasSelectedDistrict = state.appState?.selectedDistrict != nil
        state.$launchState.withLock {
            $0 = hasSelectedDistrict ? .district(.guest, currentRouteId) : .festival(.guest)
        }
        state.map = state.makeMapState(userRole: .guest, currentRouteId: currentRouteId)
        state.destination = nil
        state.sheet = nil
        lastMainScreenUseCase.save(nil)
    }
}

extension RootFeature.Destination.State: Equatable {}
extension RootFeature.Destination.Action: Equatable {}
extension RootFeature.Sheet.State: Equatable {}
extension RootFeature.Sheet.Action: Equatable {}

enum IntroSheetPreparation: Equatable {
    case festival(Festival)
    case district(Festival, DistrictPack, Date?)
}
