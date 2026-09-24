//
//  PublicMapFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//

import MapKit
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct PublicMapFeature {
    struct DistrictLaunchResult: Equatable {
        let district: District
        let routeId: Route.ID?
    }
    
    enum Content: Equatable{
        case locations(Festival)
        case route(District)
    }
    
    @Reducer
    enum Destination {
        case locations(PublicLocationsFeature)
        case route(PublicRouteFeature)
    }
    
    @ObservableState
    struct State: Equatable{
        let userRole: UserRole
        let contents: [Content]
        var selectedContent: Content
        var currentPeriodId: Period.ID? = nil
        var isLoading: Bool = false
        var isDismissed: Bool = false
        @Presents var destination: Destination.State?
        @Shared var mapRegion: MKCoordinateRegion
        var toast: MapToast?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case dismissTapped
        case contentSelected(Content)
        case routePrepared(District, Route.ID?)
        case districtContentEvaluated(District, Bool)
        case districtLaunchReceived(AppResult<DistrictLaunchResult>)
        case errorCaught(AppError)
        case toastDismissed
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(SceneDataFetcherKey.self) var sceneDataFetcher
    @Dependency(\.publicMapAdUsecase) var publicMapAdUsecase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMapFeature> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                state.toast = nil
                if state.destination?.route?.routes.isEmpty ?? false,
                    state.destination?.route?.float == nil {
                    state.toast = .notice("現在、配信中の情報はありません。")
                } else if state.destination?.locations?.floats.isEmpty ?? false {
                    state.toast = .notice("現在、配信中の情報はありません。")
                }
                return .run{ send in
                    await mapLocationProvider.requestPermission()
                    await mapLocationProvider.startTracking()
                    await publicMapAdUsecase.prepareSession()
                }
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
                state.toast = nil
                state.selectedContent = value
                switch value {
                case .locations(let festival):
                    state.destination = .locations(
                        PublicLocationsFeature.State(
                            festival,
                            mapRegion: state.$mapRegion
                        )
                    )
                    return .none
                case .route(let district):
                    state.isLoading = true
                    return districtLaunchEffect(
                        userRole: state.userRole,
                        district: district,
                        periodId: state.currentPeriodId
                    )
                }
            case .districtLaunchReceived(.success(let result)):
                return .send(.routePrepared(result.district, result.routeId))
            case .districtLaunchReceived(.failure(let error)):
                state.isLoading = false
                state.toast = .error(error, title: "地区情報を取得できませんでした")
                return .none
            case .routePrepared(let district, let routeId):
                state.isLoading = false
                state.toast = nil
                if let routeId,
                   let route = FetchOne(Route.find(routeId)).wrappedValue {
                    state.currentPeriodId = route.periodId
                }
                state.destination = .route(
                    PublicRouteFeature.State(
                        district,
                        routeId: routeId,
                        mapRegion: state.$mapRegion
                    )
                )
                let hasDisplayableContent = state.destination?.route?.hasDisplayableContent ?? false
                return .send(.districtContentEvaluated(district, hasDisplayableContent))
            case .districtContentEvaluated(let district, let hasDisplayableContent):
                if !hasDisplayableContent {
                    state.toast = .notice("現在、配信中の情報はありません。")
                }
                return .run { [userRole = state.userRole, districtId = district.id] _ in
                    await publicMapAdUsecase.handleDistrictSelectionResult(
                        userRole: userRole,
                        districtId: districtId,
                        hasDisplayableContent: hasDisplayableContent
                    )
                }
            case .errorCaught(let error):
                state.toast = .error(error, title: "地図を表示できませんでした")
                return .none
            case .toastDismissed:
                state.toast = nil
                return .none
            case .destination:
                return destinationAction(state: &state, action: action)
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    private func destinationAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .destination(.presented(.route(.selected(let entry)))):
            state.currentPeriodId = entry.period.id
            state.toast = nil
            return .none
        case .destination(.presented(.route(.toastRequested(let toast)))):
            state.toast = toast
            return .none
        case .destination(.presented(.locations(.toastRequested(let toast)))):
            state.toast = toast
            return .none
        default:
            return .none
        }
    }
    
    func districtLaunchEffect(
        userRole: UserRole,
        district: District,
        periodId: Period.ID?
    ) -> Effect<Action> {
        .task(Action.districtLaunchReceived) {
            let routeId = try await publicMapAdUsecase.handleDistrictSelection(
                districtId: district.id,
                periodId: periodId
            )
            return DistrictLaunchResult(district: district, routeId: routeId)
        }
    }
}

extension PublicMapFeature.Destination.State: Equatable {}
extension PublicMapFeature.Destination.Action: Equatable {}

extension PublicMapFeature.Content: Identifiable, Hashable  {
    var id:String {
        switch self {
        case .locations(let festival):
            return festival.id
        case .route(let district):
            return district.id
        }
    }
    
    var name: String {
        switch self {
        case .locations(let festival):
            return festival.name
        case .route(let district):
            return district.name
        }
    }
    
    var text: String {
        switch self {
        case .locations:
            return "現在地一覧"
        case .route(let district):
            return district.name
        }
    }
    
    var origin: Coordinate {
        switch self {
        case .locations(let festival):
            return festival.base
        case .route(let district):
            return district.base ?? Coordinate(latitude: 0, longitude: 0)
        }
    }
}

extension PublicMapFeature.State {
    init(festival: Festival, district: District, routeId: Route.ID?, userRole: UserRole) {
        self.userRole = userRole
        let districts: [District] = FetchAll(District.where{ $0.festivalId.eq(festival.id) }).wrappedValue
        let locations: PublicMapFeature.Content = .locations(festival)
        let contents = [locations]
            + districts.prioritizing(districtId: district.id)
            .map{ PublicMapFeature.Content.route($0) }
            
        let selected = contents[1]
        self.contents = contents
        self.selectedContent = selected
        if let routeId,
           let route = FetchOne(Route.find(routeId)).wrappedValue {
            self.currentPeriodId = route.periodId
        } else {
            self.currentPeriodId = nil
        }
        
        self._mapRegion = Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta))
        self.destination = .route(
            PublicRouteFeature.State(
                district,
                routeId: routeId,
                mapRegion: $mapRegion
            )
        )
    }
    
    init(
        festival: Festival,
        userRole: UserRole
    ){
        self.userRole = userRole
        let districts = FetchAll(District.where{ $0.festivalId.eq(festival.id) }).wrappedValue
        let selected: PublicMapFeature.Content = .locations(festival)
        let contents = [selected] + districts.sorted().map{ PublicMapFeature.Content.route($0) }
        
        self.contents = contents
        self.selectedContent = selected
        self.currentPeriodId = nil
        
        self._mapRegion = Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta))
        self.destination = .locations(
            PublicLocationsFeature.State(
                festival,
                mapRegion: $mapRegion
            )
        )
    }
}
