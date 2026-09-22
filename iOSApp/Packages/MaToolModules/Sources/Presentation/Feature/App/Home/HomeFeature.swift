import iOSShared
import Application
import View
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct HomeFeature {
    typealias Tab = HomeTab

    @ObservableState
    struct State: Equatable {
        var userRole: UserRole
        var currentRouteID: Route.ID?
        var selectedTab: Tab = .map
        @Shared var publicSelection: PublicTabSelection

        var map: MapTabFeature.State
        var info: InfoListFeature.State
        var settings: SettingsFeature.State
        var adminDistrict: DistrictDashboardFeature.State?
        var adminFestival: FestivalDashboardFeature.State?

        @Presents var alert: AlertFeature.State?

        init(
            userRole: UserRole,
            festival: Festival,
            district: District? = nil,
            routeID: Route.ID? = nil,
            isPublicSelectionLinked: Bool = true
        ) {
            self.userRole = userRole
            self.currentRouteID = routeID
            let context = PublicSelectionContext(
                festivalID: festival.id,
                districtID: district?.id,
                routeID: routeID
            )
            let publicSelection: Shared<PublicTabSelection> = Shared(
                value: .initial(linked: isPublicSelectionLinked, context: context)
            )
            self._publicSelection = publicSelection
            self.map = .init(
                userRole: userRole,
                festival: festival,
                district: district,
                routeID: routeID,
                publicSelection: publicSelection
            )
            self.info = .init(
                festival: festival,
                district: district,
                routeID: routeID,
                publicSelection: publicSelection
            )
            self.settings = .init(publicSelection: publicSelection)
            self.adminDistrict = nil
            self.adminFestival = nil
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case initialize
        case festivalListRefreshReceived(VoidAppResult)
        case tabSelected(Tab)
        case map(MapTabFeature.Action)
        case info(InfoListFeature.Action)
        case settings(SettingsFeature.Action)
        case adminDistrict(DistrictDashboardFeature.Action)
        case adminFestival(FestivalDashboardFeature.Action)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(SceneUsecaseKey.self) private var sceneUsecase

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.map, action: \.map) {
            MapTabFeature()
        }
        Scope(state: \.info, action: \.info) {
            InfoListFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .initialize:
                let context = PublicSelectionContext(
                    festivalID: state.map.selectedFestival?.id,
                    districtID: state.map.selectedDistrict?.id,
                    routeID: state.currentRouteID
                )
                state.map.isFestivalListLoading = true
                state.info.isFestivalListLoading = true
                return .merge(
                    .send(.info(.selectionRequested(context))),
                    .task(Action.festivalListRefreshReceived) {
                        try await sceneUsecase.refreshFestivals()
                    }
                )

            case .festivalListRefreshReceived(.success):
                state.map.isFestivalListLoading = false
                state.info.isFestivalListLoading = false
                return .none

            case .festivalListRefreshReceived(.failure(let error)):
                state.map.isFestivalListLoading = false
                state.info.isFestivalListLoading = false
                state.alert = .error("祭典一覧の取得に失敗しました。\n\(error.message)")
                return .none

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .map(.delegate(.selectionChanged(let context))):
                state.currentRouteID = context.routeID
                state.$publicSelection.withLock {
                    $0 = $0.updating(context, from: .map)
                }
                guard state.publicSelection.isLinked else { return .none }
                return .send(.info(.selectionRequested(context)))

            case .map(.delegate(.navigationPopped)):
                guard state.publicSelection.isLinked else { return .none }
                return .send(.info(.navigationPopRequested))

            case .map(.delegate(.userRoleChanged(let userRole))):
                updateRole(userRole, state: &state)
                return .none

            case .map:
                return .none

            case .info(.delegate(.mapRequested(let context))):
                state.selectedTab = .map
                return .send(.map(.selectionRequested(context)))

            case .info(.delegate(.selectionChanged(let context))):
                state.$publicSelection.withLock {
                    $0 = $0.updating(context, from: .info)
                }
                guard state.publicSelection.isLinked else { return .none }
                return .send(.map(.selectionRequested(context)))

            case .info(.delegate(.navigationPopped)):
                guard state.publicSelection.isLinked else { return .none }
                return .send(.map(.navigationPopRequested))

            case .info:
                return .none

            case .settings(.delegate(.userRoleChanged(let userRole))):
                updateRole(userRole, state: &state)
                return .none

            case .settings(.festivalSelectReceived(.success(.changed(let userRole)))):
                guard let festival = state.settings.selectedFestival else { return .none }
                updateRole(userRole, state: &state)
                state.currentRouteID = nil
                let context = PublicSelectionContext(festivalID: festival.id)
                return .merge(
                    .send(.map(.selectionRequested(context))),
                    .send(.info(.selectionRequested(context)))
                )

            case .settings(.binding(\.isMapInfoLinked)):
                let mapContext = state.publicSelection.context(for: .map)
                    ?? .init(
                        festivalID: state.map.selectedFestival?.id,
                        districtID: state.map.selectedDistrict?.id,
                        routeID: state.currentRouteID
                    )
                let infoContext = state.publicSelection.context(for: .info)
                    ?? .init(
                        festivalID: state.info.selectedFestival?.id,
                        districtID: state.info.selectedDistrictID,
                        routeID: state.info.selectedRouteID
                    )
                let enabled = state.settings.isMapInfoLinked
                state.$publicSelection.withLock {
                    $0 = $0.settingLinking(
                        enabled,
                        mapContext: mapContext,
                        infoContext: infoContext
                    )
                }
                guard enabled,
                      let context = state.publicSelection.context(for: .map)
                        ?? state.publicSelection.context(for: .info) else {
                    return .none
                }
                return .send(.info(.selectionRequested(context)))

            case .settings(.delegate(.publicSelectionLinkChanged)):
                return .none

            case .settings(.districtSelectReceived(.success(let routeID))):
                guard let festival = state.settings.selectedFestival,
                      let district = state.settings.selectedDistrict else { return .none }
                state.currentRouteID = routeID
                let context = PublicSelectionContext(
                    festivalID: festival.id,
                    districtID: district.id,
                    routeID: routeID
                )
                return .merge(
                    .send(.map(.selectionRequested(context))),
                    .send(.info(.selectionRequested(context)))
                )

            case .settings:
                return .none

            case .adminDistrict(.signOutReceived(.success(let userRole))),
                    .adminFestival(.signOutReceived(.success(let userRole))):
                updateRole(userRole, state: &state)
                return .none

            case .adminDistrict, .adminFestival:
                return .none

            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.adminDistrict, action: \.adminDistrict) {
            DistrictDashboardFeature()
        }
        .ifLet(\.adminFestival, action: \.adminFestival) {
            FestivalDashboardFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func updateRole(_ userRole: UserRole, state: inout State) {
        state.userRole = userRole
        state.map.userRole = userRole

        switch userRole {
        case .guest:
            state.adminDistrict = nil
            state.adminFestival = nil
        case .district(let id):
            state.adminFestival = nil
            if let district = FetchOne(District.find(id)).wrappedValue {
                state.adminDistrict = .init(district)
            }
        case .headquarter(let id):
            state.adminDistrict = nil
            if let festival = FetchOne(Festival.find(id)).wrappedValue {
                state.adminFestival = .init(festival)
            }
        }
    }
}

extension HomeFeature.State {
    var isGuest: Bool {
        if case .guest = userRole { return true }
        return false
    }
}
