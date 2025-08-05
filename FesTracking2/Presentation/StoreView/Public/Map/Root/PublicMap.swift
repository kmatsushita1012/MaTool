//
//  RouteDetail.swift
//  FesTracking2
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
        @Presents var destination: Destination.State?
        @Shared var mapRegion: MKCoordinateRegion
        @Presents var alert: Alert.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case homeTapped
        case contentSelected(Content)
        case routePrepared(
            id: String,
            routesResult: Result<[RouteSummary], ApiError>,
            currentResult: Result<RouteInfo, ApiError>,
            locationResult: Result<LocationInfo, ApiError>
        )
        case locationsReceived(
            id: String,
            locationsResult: Result<[LocationInfo],ApiError>
        )
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMap> {
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .homeTapped:
                return .run{ _ in
                    await dismiss()
                }
            case .contentSelected(let value):
                state.selectedContent = value
                switch value {
                //TODO　mapRegionの変更ができてない
                case .locations(let id, _ , let origin):
                    return locationsEffect(id)
                case .route(let id, _ , let origin):
                    return routeEffect(id)
                }
            case let .routePrepared(
                id,
                routesResult,
                currentResult,
                locationResult,
            ):
                let mapRegion = makeRegion(route: currentResult.value, location: locationResult.value, origin: state.selectedContent.origin, spanDelta: spanDelta)
                state.$mapRegion.withLock{ $0 = mapRegion }
                state.destination = .route(
                    PublicRoute.State(
                        id: id,
                        routes: routesResult.value,
                        selectedRoute: currentResult.value,
                        location: locationResult.value,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .locationsReceived(let id, .success(let value)):
                state.destination = .locations(
                    PublicLocations.State(
                        regionId: id,
                        locations: value,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .locationsReceived(_, .failure(let error)):
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
            let accessToken = await authService.getAccessToken()
            
            async let routesTask = apiRepository.getRoutes(id, accessToken)
            async let currentTask = apiRepository.getCurrentRoute(id, accessToken)
            async let locationTask = apiRepository.getLocation(id, accessToken)
            
            let (routesResult, currentResult, locationResult) = await (routesTask, currentTask, locationTask)
            await send(
                .routePrepared(
                    id: id,
                    routesResult: routesResult,
                    currentResult: currentResult,
                    locationResult: locationResult,
                )
            )
        }
    }
    
    
    func locationsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let accessToken = await authService.getAccessToken()
            
            let locationsResult = await apiRepository.getLocations(id, accessToken)
            
            await send(.locationsReceived(id: id, locationsResult: locationsResult))
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
            + districts.map{ PublicMap.Content.from(district: $0, origin: region.base) }
        let selected = contents.first(where: \.id, equals: id) ?? locations
        self.contents = contents
        self.selectedContent = selected
        let mapRegion = Shared(value: makeRegion(route: current, location: location, origin: selected.origin, spanDelta: spanDelta))
        self._mapRegion = mapRegion
        self.destination = .route(
            PublicRoute.State(
                id: id,
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
