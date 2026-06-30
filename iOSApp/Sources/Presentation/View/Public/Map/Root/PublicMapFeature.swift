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
        @Presents var alert: AlertFeature.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case dismissTapped
        case contentSelected(Content)
        case routePrepared(District, Route.ID?)
        case districtLaunchReceived(AppResult<DistrictLaunchResult>)
        case errorCaught(AppError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(\.publicMapAdUsecase) var publicMapAdUsecase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMapFeature> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                if state.destination?.route?.routes.isEmpty ?? false,
                    state.destination?.route?.float == nil {
                    state.alert = AlertFeature.notice("配信停止中です。")
                } else if state.destination?.locations?.floats.isEmpty ?? false {
                    state.alert = AlertFeature.notice("配信停止中です。")
                }
                return .run{ send in
                    await locationProvider.requestPermission()
                    await locationProvider.startTracking(backgroundUpdatesAllowed: false)
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
                let wasLocations: Bool = {
                    if case .locations = state.selectedContent {
                        return true
                    }
                    return false
                }()
                state.selectedContent = value
                switch value {
                case .locations(let festival):
                    state.currentPeriodId = nil
                    state.destination = .locations(
                        PublicLocationsFeature.State(
                            festival,
                            mapRegion: state.$mapRegion
                        )
                    )
                    return .none
                case .route(let district):
                    if wasLocations {
                        state.currentPeriodId = nil
                    }
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
                state.alert = .error(error)
                return .none
            case .routePrepared(let district, let routeId):
                state.isLoading = false
                if let routeId,
                   let route = FetchOne(Route.find(routeId)).wrappedValue {
                    state.currentPeriodId = route.periodId
                } else {
                    state.currentPeriodId = nil
                }
                state.destination = .route(
                    PublicRouteFeature.State(
                        district,
                        routeId: routeId,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .errorCaught(let error):
                state.alert = .error(error)
                return .none
            case .destination:
                return destinationAction(state: &state, action: action)
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    private func destinationAction(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .destination(.presented(.route(.selected(let entry)))):
            state.currentPeriodId = entry.period.id
            return .run { [userRole = state.userRole, districtId = entry.route.districtId] _ in
                await publicMapAdUsecase.handlePeriodSelection(
                    userRole: userRole,
                    districtId: districtId
                )
            }
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
                userRole: userRole,
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
