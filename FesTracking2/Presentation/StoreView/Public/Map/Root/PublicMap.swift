//
//  RouteDetail.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//
import ComposableArchitecture

@Reducer
struct PublicMap{
    
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.accessToken) var accessToken
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    enum Content: Equatable{
        case locations
        case route(PublicDistrict)
    }
    
    @Reducer
    enum Destination {
        case route(PublicRouteMap)
        case locations(PublicLocationsMap)
    }
    
    @ObservableState
    struct State: Equatable{
        var error: String?
        var districtPicker: PickerFeature<Content>.State?
        var routePicker: PickerFeature<RouteSummary>.State?
        @Presents var map: Destination.State?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case districtPicker(PickerFeature<Content>.Action)
        case routePicker(PickerFeature<RouteSummary>.Action)
        case map(PresentationAction<Destination.Action>)
        case onAppear
        case districtsReceived(Result<[PublicDistrict],ApiError>)
        case routesReceived(Result<[RouteSummary],ApiError>)
        case routeReceived(route: Result<PublicRoute,ApiError>, location: Result<PublicLocation?,ApiError>)
        case locationsReceived(Result<[PublicLocation],ApiError>)
        case locationReceived(location: Result<PublicLocation,ApiError>)
        case homeTapped
    }
    
    var body: some ReducerOf<PublicMap> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                //TODO
                guard let regionId = userDefaultsClient.stringForKey(defaultRegionKey) else {
                    return .none
                }
                if let districtId = userDefaultsClient.stringForKey(defaultDistrictKey){
                    return .merge(
                        routeEffect(districtId, accessToken: accessToken.value),
                        routesEffect(districtId,accessToken: accessToken.value),
                        districtsEffect(regionId)
                    )
                }else{
                    return .merge(
                        locationsEffect(regionId, accessToken: accessToken.value),
                        districtsEffect(regionId)
                    )
                }
            case .districtsReceived(let result):
                switch result {
                case .success(let districts):
                    let items = [Content.locations] + districts.map{ Content.route($0) }
                    //TODO
                    if let districtId = userDefaultsClient.stringForKey(defaultDistrictKey),
                       let selected = districts.first(where: { $0.id == districtId }) {
                        state.districtPicker = PickerFeature.State(items: items, selected: Content.route(selected))
                    }else{
                        state.districtPicker = PickerFeature.State(items: items, selected: Content.locations)
                    }
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case .routesReceived(let result):
                switch result {
                case .success(var routes):
                    state.routePicker = PickerFeature.State(items: routes.sorted())
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case let .routeReceived(routeResult, locationResult):
                var route: PublicRoute?
                var location: PublicLocation?
                switch routeResult {
                case .success(let value):
                    route = value
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                switch locationResult {
                case .success(let value):
                    location = value
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                state.map = .route(PublicRouteMap.State(route: route, location: location))
                return .none
            case .locationsReceived(locations: let result):
                switch result {
                case .success(let locations):
                    state.map = .locations(PublicLocationsMap.State(locations: locations))
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case .locationReceived(location: let result):
                switch result {
                case .success(let value):
                    if case let .route(routeState) = state.map{
                        state.map = .route(PublicRouteMap.State(route: routeState.route, location: value))
                    }
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case .binding(_):
                return .none
            case .districtPicker(.selected(let content)):
                state.routePicker = nil
                switch content {
                case .locations:
                    //TODO
                    return locationsEffect(Region.sample.id, accessToken: accessToken.value)
                case .route(let district):
                    return .merge(
                        routeEffect(district.id, accessToken: accessToken.value),
                        routesEffect(district.id, accessToken: accessToken.value)
                    )
                }
            case .routePicker(.selected(let route)):
                return routeEffect(route, accessToken: accessToken.value)
            case .districtPicker(_),.routePicker(_), .map(_), .homeTapped:
                return .none
            }
        }
        .ifLet(\.$map, action: \.map)
        .ifLet(\.districtPicker, action: \.districtPicker) {
            PickerFeature<Content>()
        }
        .ifLet(\.routePicker, action: \.routePicker) {
            PickerFeature<RouteSummary>()
        }
        
    }
    
    func routeEffect(_ id: String, accessToken: String?) -> Effect<Action> {
        .run { send in
            async let routeTask = apiClient.getCurrentRoute(id, accessToken)
            async let locationTask = apiClient.getLocation(id, accessToken)
            let (routeResult, locationResult) = await (routeTask, locationTask)
            await send(.routeReceived(route: routeResult, location: locationResult))
        }
    }
    
    func routeEffect(_ summary: RouteSummary, accessToken: String?) -> Effect<Action> {
        .run { send in
            async let routeTask = apiClient.getRoute(summary.id, accessToken)
            async let locationTask = apiClient.getLocation(summary.districtId, accessToken)
            let (routeResult, locationResult) = await (routeTask, locationTask)
            await send(.routeReceived(route: routeResult, location: locationResult))
        }
    }
    
    func districtsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let result = await apiClient.getDistricts(id);
            await send(.districtsReceived(result))
        }
    }
    
    func routesEffect(_ id: String, accessToken: String?) -> Effect<Action> {
        .run { send in
            let result = await apiClient.getRoutes(id, accessToken);
            await send(.routesReceived(result))
        }
    }
    
    func locationsEffect(_ id: String, accessToken: String?) -> Effect<Action> {
        .run { send in
            let result = await apiClient.getLocations(id, accessToken);
            await send(.locationsReceived(result))
        }
    }
}

extension PublicMap.Destination.State: Equatable {}
extension PublicMap.Destination.Action: Equatable {}

extension PublicMap.Content: Identifiable,Hashable  {
    var id:String {
        switch self {
        case .locations:
            return "location"
        case .route(let district):
            return "route-\(district.id)"
        }
    }
    
    var text: String {
        switch self {
        case .locations:
            return "全体"
        case .route(let district):
            return district.name
        }
    }
}
