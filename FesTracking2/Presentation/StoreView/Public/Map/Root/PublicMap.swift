//
//  RouteDetail.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/02.
//
import ComposableArchitecture

@Reducer
struct PublicMap{
    
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
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case districtPicker(PickerFeature<Content>.Action)
        case routePicker(PickerFeature<RouteSummary>.Action)
        case map(PresentationAction<Destination.Action>)
        case onAppear
        case districtsReceived(Result<[PublicDistrict],ApiError>)
        case routesReceived(Result<[RouteSummary],ApiError>)
        case routeReceived(
            route: Result<PublicRoute,ApiError>,
            location: Result<PublicLocation?,ApiError>,
            tool: Result<DistrictTool, ApiError>
        )
        case locationsReceived(
            locations: Result<[PublicLocation],ApiError>,
            region: Result<Region, ApiError>
        )
        case locationReceived(Result<PublicLocation,ApiError>)
        case homeTapped
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMap> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                //TODO
                guard let regionId = userDefaultsClient.string(defaultRegionKey) else {
                    return .none
                }
                if let districtId = userDefaultsClient.string(defaultDistrictKey){
                    return .merge(
                        routeEffect(districtId),
                        routesEffect(districtId),
                        districtsEffect(regionId)
                    )
                }else{
                    return .merge(
                        locationsEffect(regionId),
                        districtsEffect(regionId)
                    )
                }
            case .homeTapped:
                return .run{ _ in
                    await dismiss()
                }
            case .districtsReceived(let result):
                switch result {
                case .success(let districts):
                    let items = [Content.locations] + districts.map{ Content.route($0) }
                    if let districtId = userDefaultsClient.string(defaultDistrictKey),
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
                case .success(let routes):
                    state.routePicker = PickerFeature.State(items: routes.sorted())
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case let .routeReceived(routeResult, locationResult, toolResult):
                switch (routeResult,locationResult,toolResult) {
                case (.success(let route), .success(let location), .success(let tool)):
                        state.map = .route(
                            PublicRouteMap.State(
                                route: route,
                                location: location,
                                origin: tool.base
                            )
                        )
                      return .none
                case (.failure(let error), _, _),
                      (_, .failure(let error), _),
                      (_, _, .failure(let error)):
                    state.error = error.localizedDescription
                      return .none
                }
            case .locationsReceived(let locationsResult,let toolResult):
                switch (locationsResult, toolResult) {
                case (.success(let locations), .success(let tool)):
                    state.map = .locations(
                        PublicLocationsMap.State(
                            locations: locations,
                            origin: tool.base
                        )
                    )
                    return .none
                case (.failure(let error), _),
                    (_, .failure(let error)):
                    state.error = error.localizedDescription
                    return .none
                }
            case .locationReceived(location: let result):
                switch result {
                case .success(let value):
                    if case let .route(routeState) = state.map{
                        state.map = .route(PublicRouteMap.State(route: routeState.route, location: value, origin: routeState.origin))
                    }
                case .failure(let error):
                    state.error = error.localizedDescription
                }
                return .none
            case .binding:
                return .none
            case .districtPicker(.selected(let content)):
                state.routePicker = nil
                switch content {
                case .locations:
                    //TODO
                    return locationsEffect(Region.sample.id)
                case .route(let district):
                    return .merge(
                        routeEffect(district.id),
                        routesEffect(district.id)
                    )
                }
            case .routePicker(.selected(let route)):
                return routeEffect(route)
            case .districtPicker,
                .routePicker,
                .map:
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
    
    func routeEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let accessToken = await authService.getAccessToken()
            async let routeTask = apiRepository.getCurrentRoute(id, accessToken)
            async let locationTask = apiRepository.getLocation(id, accessToken)
            async let toolTask = apiRepository.getTool(id, accessToken)
            let (routeResult, locationResult, toolResult) = await (routeTask, locationTask, toolTask)
            await send(
                .routeReceived(
                    route: routeResult,
                    location: locationResult,
                    tool: toolResult
                )
            )
        }
    }
    
    func routeEffect(_ summary: RouteSummary) -> Effect<Action> {
        .run { send in
            let accessToken = await authService.getAccessToken()
            async let routeTask = apiRepository.getRoute(summary.id, accessToken)
            async let locationTask = apiRepository.getLocation(summary.districtId, accessToken)
            async let toolTask = apiRepository.getTool(summary.districtId, accessToken)
            let (routeResult, locationResult, toolResult) = await (routeTask, locationTask, toolTask)
            await send(
                .routeReceived(
                    route: routeResult,
                    location: locationResult,
                    tool: toolResult
                )
            )
        }
    }
    
    func districtsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let result = await apiRepository.getDistricts(id);
            await send(.districtsReceived(result))
        }
    }
    
    func routesEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let accessToken = await authService.getAccessToken()
            let result = await apiRepository.getRoutes(id, accessToken);
            await send(.routesReceived(result))
        }
    }
    
    func locationsEffect(_ id: String) -> Effect<Action> {
        .run { send in
            let accessToken = await authService.getAccessToken()
            async let locationsTask = apiRepository.getLocations(id, accessToken)
            async let regionTask = apiRepository.getRegion(id)
            let (locationsResult, regionResult) = await (locationsTask, regionTask)
            await send(.locationsReceived(locations: locationsResult, region: regionResult))
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
