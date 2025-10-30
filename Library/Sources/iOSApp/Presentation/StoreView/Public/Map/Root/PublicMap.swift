//
//  RouteDetail.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//
import ComposableArchitecture
import MapKit

@Reducer
struct PublicMap{
    
    enum Content: Equatable{
        case locations(id: String, name: String, origin: Coordinate)
        case route(id: String, name: String, origin: Coordinate)
    }
    
    @Reducer
    enum Destination {
        case locations(PublicLocations)
        case route(PublicRoute)
    }
    
    @ObservableState
    struct State: Equatable{
        let contents: [Content]
        var selectedContent: Content
        var isLoading: Bool = false
        var isDismissed: Bool = false
        @Presents var destination: Destination.State?
        @Shared var mapRegion: MKCoordinateRegion
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case homeTapped
        case contentSelected(Content)
        case routePrepared(Result<CurrentResponse, APIError>)
        case locationsPrepared(
            id: String,
            locationsResult: Result<[LocationInfo],APIError>
        )
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMap> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                if case .route(let routeState) = state.destination,
                   routeState.items?.isEmpty ?? true,
                    routeState.route == nil,
                    routeState.location == nil {
                    state.alert = Alert.notice("配信停止中です。")
                } else if case .locations(let locationState) = state.destination,
                          locationState.locations.isEmpty {
                state.alert = Alert.notice("配信停止中です。")
                }
                return .run{ send in
                    await locationProvider.requestPermission()
                    await locationProvider.startTracking(backgroundUpdatesAllowed: false)
                }
            case .binding:
                return .none
            case .homeTapped:
                if #available(iOS 17.0, *) {
                    return .run { _ in
                        await dismiss()
                    }
                } else {
                    state.isDismissed = true
                    return .none
                }
            case .contentSelected(let value):
                state.selectedContent = value
                state.isLoading = true
                switch value {
                case .locations(let id, _ , _):
                    return locationsEffect(id)
                case .route(let id, _ , _):
                    return routeEffect(id)
                }
            case .routePrepared(.success(let value)):
                state.isLoading = false
                let id = value.districtId
                let name = value.districtName
                let routes = value.routes
                let current = value.current
                let location = value.location
                if  routes?.isEmpty ?? true && current == nil && location == nil {
                    state.alert = Alert.notice("配信停止中です。")
                }
                let mapRegion = makeRegion(
                    route: current,
                    location: location,
                    origin: state.selectedContent.origin,
                    spanDelta: spanDelta
                )
                state.$mapRegion.withLock{ $0 = mapRegion }
                state.destination = .route(
                    PublicRoute.State(
                        districtId: id,
                        name: name,
                        routes: routes,
                        selectedRoute: current,
                        location: location,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .routePrepared(.failure(let error)):
                state.isLoading = false
                if case .forbidden = error {
                    state.alert = Alert.error("配信停止中です。")
                } else {
                    state.alert = Alert.error(error.localizedDescription)
                }
                state.destination = .route(
                    PublicRoute.State(
                        districtId: state.selectedContent.id,
                        name: state.selectedContent.name,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .locationsPrepared(let id, .success(let value)):
                state.isLoading = false
                if value.isEmpty {
                    state.alert = Alert.notice("配信停止中です。")
                }
                state.destination = .locations(
                    PublicLocations.State(
                        regionId: id,
                        locations: value,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .locationsPrepared(_, .failure(let error)):
                state.isLoading = false
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .destination:
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    func routeEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let currentResult = await apiRepository.getCurrentRoute(id)
            await send(.routePrepared(currentResult))
        }
    }
    
    
    func locationsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            
            
            let locationsResult = await apiRepository.getLocations(id)
            
            await send(.locationsPrepared(id: id, locationsResult: locationsResult))
        }
    }
}

extension PublicMap.Destination.State: Equatable {}
extension PublicMap.Destination.Action: Equatable {}

extension PublicMap.Content: Identifiable,Hashable  {
    var id:String {
        switch self {
        case .locations(let id, _, _):
            return id
        case .route(let id, _, _):
            return id
        }
    }
    
    var name: String {
        switch self {
        case .locations(_, _, _):
            return id
        case .route(_, let name, _):
            return name
        }
    }
    
    var text: String {
        switch self {
        case .locations:
            return "現在地一覧"
        case .route(_,let name , _):
            return name
        }
    }
    
    var origin: Coordinate {
        switch self {
        case .locations(_, _, let origin):
            return origin
        case .route(_,_, let origin):
            return origin
        }
    }
    
    static func from(region: Region) -> Self {
        return .locations(
            id: region.id,
            name: region.name,
            origin: region.base
        )
    }
    static func from(district: PublicDistrict, origin: Coordinate) -> Self{
        return .route(
            id: district.id,
            name: district.name,
            origin: district.base ?? origin
        )
    }
}

extension PublicMap.State {
    init(
        region: Region,
        districts: [PublicDistrict],
        id: String,
        routes: [RouteSummary]?,
        current: RouteInfo?,
        location: LocationInfo?
    ) {
        let locations = PublicMap.Content.from(region: region)
        let contents = [locations]
            + districts
            .map{ PublicMap.Content.from(district: $0, origin: region.base) }
            .prioritizing(by: \.id, match: id)
        let selected = contents.first(where: \.id, equals: id) ?? locations
        self.contents = contents
        self.selectedContent = selected
        let mapRegion = Shared(value: makeRegion(route: current, location: location, origin: selected.origin, spanDelta: spanDelta))
        self._mapRegion = mapRegion
        self.destination = .route(
            PublicRoute.State(
                districtId: id,
                name: selected.name,
                routes: routes,
                selectedRoute: current,
                location: location,
                mapRegion: mapRegion
            )
        )
    }
    
    init(
        region: Region,
        districts: [PublicDistrict],
        locations: [LocationInfo]
    ){
        let selected = PublicMap.Content.from(region: region)
        let contents = [selected] + districts.map{ PublicMap.Content.from(district: $0, origin: region.base) }
        
        self.contents = contents
        self.selectedContent = selected
        
        let mapRegion = Shared(value: makeRegion(locations: locations, origin: region.base))
        self._mapRegion = mapRegion
        self.destination = .locations(
            PublicLocations.State(
                regionId: region.id,
                locations: locations,
                mapRegion: mapRegion
            )
        )
    }
}
