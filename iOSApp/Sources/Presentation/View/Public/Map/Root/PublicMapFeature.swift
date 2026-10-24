//
//  PublicMapFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//

import MapKit
import ComposableArchitecture
import Shared

@Reducer
struct PublicMapFeature {
    struct DistrictLaunchResult: Equatable {
        let districtId: District.ID
        let routeId: Route.ID?
    }
    
    enum Content: Equatable{
        case locations
        case route(District.ID)
    }
    
    @Reducer
    enum Destination {
        case locations(PublicLocationsFeature)
        case route(PublicRouteFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        let userRole: UserRole
        @Shared fileprivate var appState: AppState?

        var contents: [Content] {
            [.locations] + (appState?.routeDistrictIds.map(Content.route) ?? [])
        }
        var selectedContent: Content
        var currentPeriodId: Period.ID? {
            appState?.currentPeriod(at: .now)?.id
        }
        var contentTitles: [Content: String] {
            Dictionary(uniqueKeysWithValues: contents.map { content in
                switch content {
                case .locations:
                    return (content, "現在地一覧")
                case .route(let districtId):
                    return (content, appState?.district(id: districtId)?.name ?? "")
                }
            })
        }
        var isLoading: Bool = false
        var isDismissed: Bool = false
        @Presents var destination: Destination.State?
        @Shared var mapRegion: MKCoordinateRegion
        @Shared var toast: MapToast?

        init(
            userRole: UserRole,
            selectedContent: Content,
            appState: Shared<AppState?>,
            mapRegion: Shared<MKCoordinateRegion>,
            toast: Shared<MapToast?>
        ) {
            self.userRole = userRole
            self.selectedContent = selectedContent
            self._appState = appState
            self._mapRegion = mapRegion
            self._toast = toast
        }
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case dismissTapped
        case contentSelected(Content)
        case routePrepared(District.ID, Route.ID?)
        case districtContentEvaluated(District, Bool)
        case districtLaunchReceived(AppResult<DistrictLaunchResult>)
        case errorCaught(AppError)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(LoadDistrictStateUseCaseKey.self) var loadDistrictStateUseCase
    @Dependency(\.publicMapAdUsecase) var publicMapAdUsecase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMapFeature> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                let permissionEffect = Effect<Action>.run { send in
                    await mapLocationProvider.requestPermission()
                    await mapLocationProvider.startTracking()
                    await publicMapAdUsecase.prepareSession()
                }
                guard case .route(let districtId) = state.selectedContent,
                      let district = state.appState?.district(id: districtId),
                      state.appState?.districtState?.districtId != districtId else {
                    return permissionEffect
                }
                state.isLoading = true
                return .merge(
                    permissionEffect,
                    districtLaunchEffect(district: district, periodId: state.currentPeriodId, appState: state.$appState)
                )
            case .binding:
                return .none
            case .dismissTapped:
                if #available(iOS 17.0, *) {
                    return .dismiss
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .contentSelected(let value):
                state.$toast.withLock { $0 = nil }
                state.selectedContent = value
                switch value {
                case .locations:
                    guard let festival = state.appState?.festivalState.festival else { return .none }
                    state.destination = .locations(
                        PublicLocationsFeature.State(
                            festivalId: festival.id,
                            festival: festival,
                            appState: state.$appState,
                            mapRegion: state.$mapRegion,
                            toast: state.$toast
                        )
                    )
                    return .none
                case .route(let districtId):
                    guard let district = state.appState?.district(id: districtId) else {
                        return .none
                    }
                    state.isLoading = true
                    return districtLaunchEffect(
                        district: district,
                        periodId: state.currentPeriodId,
                        appState: state.$appState
                    )
                }
            case .districtLaunchReceived(.success(let result)):
                return .send(.routePrepared(result.districtId, result.routeId))
            case .districtLaunchReceived(.failure(let error)):
                state.isLoading = false
                state.$toast.withLock { $0 = .error(error, title: "地区情報を取得できませんでした") }
                return .none
            case .routePrepared(let districtId, let routeId):
                state.isLoading = false
                guard let district = state.appState?.district(id: districtId) else {
                    return .send(.errorCaught(.be(.notFound("地区が見つかりません。"))))
                }
                state.destination = .route(
                    PublicRouteFeature.State(
                        districtId: district.id,
                        district: district,
                        routeId: routeId,
                        appState: state.$appState,
                        mapRegion: state.$mapRegion,
                        toast: state.$toast
                    )
                )
                let hasDisplayableContent = state.destination?.route?.hasDisplayableContent ?? false
                return .send(.districtContentEvaluated(district, hasDisplayableContent))
            case .districtContentEvaluated(let district, let hasDisplayableContent):
                return .run { [userRole = state.userRole, districtId = district.id] _ in
                    await publicMapAdUsecase.handleDistrictSelectionResult(
                        userRole: userRole,
                        districtId: districtId,
                        hasDisplayableContent: hasDisplayableContent
                    )
                }
            case .errorCaught(let error):
                state.$toast.withLock { $0 = .error(error, title: "地図を表示できませんでした") }
                return .none
            case .destination:
                return destinationAction(state: &state, action: action)
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    private func destinationAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        default:
            return .none
        }
    }

    func districtLaunchEffect(
        district: District,
        periodId: Period.ID?,
        appState: Shared<AppState?>
    ) -> Effect<Action> {
        .task(Action.districtLaunchReceived) {
            let response = try await loadDistrictStateUseCase(
                districtId: district.id,
                periodId: periodId,
                appState: appState
            )
            return DistrictLaunchResult(districtId: district.id, routeId: response.currentRouteId)
        }
    }
}

extension PublicMapFeature.Destination.State: Equatable {}
extension PublicMapFeature.Destination.Action: Equatable {}

extension PublicMapFeature.Content: Identifiable, Hashable  {
    var id:String {
        switch self {
        case .locations:
            return "locations"
        case .route(let districtId):
            return districtId
        }
    }
}

extension PublicMapFeature.State {
    init(
        festival: Festival,
        userRole: UserRole,
        appState: Shared<AppState?>
    ){
        self.init(
            userRole: userRole,
            selectedContent: .locations,
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
        self.destination = .locations(
            PublicLocationsFeature.State(
                festivalId: festival.id,
                festival: festival,
                appState: appState,
                mapRegion: $mapRegion,
                toast: $toast
            )
        )
    }

    init(festival: Festival, district: District, routeId: Route.ID?, userRole: UserRole, appState: Shared<AppState?>) {
        self.init(
            userRole: userRole,
            selectedContent: .route(district.id),
            appState: appState,
            mapRegion: Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta)),
            toast: Shared(value: nil)
        )
        if appState.wrappedValue?.districtState?.districtId == district.id {
            self.destination = .route(
                PublicRouteFeature.State(
                    districtId: district.id,
                    district: district,
                    routeId: routeId,
                    appState: appState,
                    mapRegion: $mapRegion,
                    toast: $toast
                )
            )
        }
    }
}
