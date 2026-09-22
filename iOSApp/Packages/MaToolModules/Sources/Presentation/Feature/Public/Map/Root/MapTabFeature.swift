import iOSShared
import Application
import View
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct MapTabFeature {
    @Reducer
    enum Destination {
        case map(PublicMapFeature)
    }

    enum Delegate: Equatable {
        case selectionChanged(PublicSelectionContext)
        case userRoleChanged(UserRole)
        case navigationPopped
    }

    @ObservableState
    struct State: Equatable {
        @FetchAll var festivals: [Festival]
        var selectedFestival: Festival?
        var selectedDistrict: District?
        var routeID: Route.ID?
        var userRole: UserRole
        @Shared var publicSelection: PublicTabSelection
        var isLoading = false
        var isFestivalListLoading = false
        var isDismissed = false
        @Presents var destination: Destination.State?
        @Presents var alert: AlertFeature.State?

        init(
            userRole: UserRole,
            festival: Festival? = nil,
            district: District? = nil,
            routeID: Route.ID? = nil,
            publicSelection: Shared<PublicTabSelection>? = nil
        ) {
            self._festivals = FetchAll()
            self.selectedFestival = festival
            self.selectedDistrict = district
            self.routeID = routeID
            self.userRole = userRole
            let context = PublicSelectionContext(
                festivalID: festival?.id,
                districtID: district?.id,
                routeID: routeID
            )
            self._publicSelection = publicSelection ?? Shared(
                value: .initial(linked: true, context: context)
            )

            if let festival {
                if let district {
                    self.destination = .map(
                        PublicMapFeature.State(
                            festival: festival,
                            district: district,
                            routeId: routeID,
                            userRole: userRole
                        )
                    )
                } else {
                    self.destination = .map(
                        PublicMapFeature.State(
                            festival: festival,
                            userRole: userRole
                        )
                    )
                }
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case festivalSelected(Festival)
        case festivalSelectionReceived(AppResult<FestivalSelectionResult>)
        case selectionRequested(PublicSelectionContext)
        case navigationPopRequested
        case userRoleUpdated(UserRole)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
        case delegate(Delegate)
    }

    @Dependency(SceneUsecaseKey.self) private var sceneUsecase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .festivalSelected(let festival):
                state.selectedFestival = festival
                state.selectedDistrict = nil
                state.routeID = nil
                state.$publicSelection.withLock {
                    $0 = $0.updating(.init(festivalID: festival.id), from: .map)
                }
                state.isLoading = true
                return .task(Action.festivalSelectionReceived) {
                    try await sceneUsecase.select(festivalId: festival.id)
                }

            case .festivalSelectionReceived(.success(let result)):
                state.isLoading = false
                guard let festival = state.selectedFestival else {
                    return .none
                }

                state.selectedDistrict = nil
                state.routeID = nil
                state.$publicSelection.withLock {
                    $0 = $0.updating(.init(festivalID: festival.id), from: .map)
                }
                state.destination = .map(
                    PublicMapFeature.State(festival: festival, userRole: state.userRole)
                )
                if case .changed(let userRole) = result {
                    state.userRole = userRole
                    return .merge(
                        .send(.userRoleUpdated(userRole)),
                        .send(.delegate(.userRoleChanged(userRole))),
                        .send(.delegate(.selectionChanged(.init(festivalID: festival.id))))
                    )
                }
                return .send(.delegate(.selectionChanged(.init(festivalID: festival.id))))

            case .festivalSelectionReceived(.failure(let error)):
                state.isLoading = false
                state.alert = .error(error.localizedDescription)
                return .none

            case .selectionRequested(let context):
                guard let festivalID = context.festivalID,
                      let festival = FetchOne(Festival.find(festivalID)).wrappedValue else {
                    state.alert = .error("祭典情報の取得に失敗しました")
                    return .none
                }
                let district = context.districtID.flatMap {
                    FetchOne(District.find($0)).wrappedValue
                }
                state.selectedFestival = festival
                state.selectedDistrict = district
                state.routeID = context.routeID
                state.$publicSelection.withLock {
                    $0 = $0.updating(context, from: .map)
                }
                state.destination = .map(
                    makeMapState(
                        festival: festival,
                        district: district,
                        routeID: context.routeID,
                        userRole: state.userRole
                    )
                )
                return .none

            case .navigationPopRequested:
                state.destination = nil
                return .none

            case .userRoleUpdated(let userRole):
                state.userRole = userRole
                if case .map(var mapState) = state.destination {
                    mapState.userRole = userRole
                    state.destination = .map(mapState)
                }
                return .none

            case .destination(.presented(.map(.contentSelected(let content)))):
                let context: PublicSelectionContext
                switch content {
                case .locations(let festival):
                    state.selectedFestival = festival
                    state.selectedDistrict = nil
                    state.routeID = nil
                    context = .init(festivalID: festival.id)
                case .route(let district):
                    state.selectedDistrict = district
                    state.routeID = nil
                    context = .init(
                        festivalID: district.festivalId,
                        districtID: district.id
                    )
                }
                state.$publicSelection.withLock {
                    $0 = $0.updating(context, from: .map)
                }
                return .send(.delegate(.selectionChanged(context)))

            case .destination(.presented(.map(.routePrepared(let district, let routeID)))):
                state.selectedDistrict = district
                state.routeID = routeID
                let context = PublicSelectionContext(
                    festivalID: district.festivalId,
                    districtID: district.id,
                    routeID: routeID
                )
                state.$publicSelection.withLock {
                    $0 = $0.updating(context, from: .map)
                }
                return .send(
                    .delegate(
                        .selectionChanged(
                            context
                        )
                    )
                )

            case .destination(.dismiss):
                state.destination = nil
                return .send(.delegate(.navigationPopped))

            case .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    private func makeMapState(
        festival: Festival,
        district: District?,
        routeID: Route.ID?,
        userRole: UserRole
    ) -> PublicMapFeature.State {
        if let district {
            return .init(
                festival: festival,
                district: district,
                routeId: routeID,
                userRole: userRole
            )
        }
        return .init(festival: festival, userRole: userRole)
    }
}

extension MapTabFeature.Destination.State: Equatable {}
extension MapTabFeature.Destination.Action: Equatable {}
