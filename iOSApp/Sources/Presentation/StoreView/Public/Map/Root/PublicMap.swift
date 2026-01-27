//
//  RouteDetail.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/02.
//

import MapKit
import ComposableArchitecture
import Shared
import SQLiteData

@Reducer
struct PublicMap{
    
    enum Content: Equatable{
        case locations(Festival)
        case route(District)
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
        case routePrepared(District, Route.ID?)
        case errorCaught(APIError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(SceneDataFetcherKey.self) var sceneDataFetcher
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<PublicMap> {
        Reduce{ state, action in
            switch action {
            case .onAppear:
                if state.destination?.route?.routes.isEmpty ?? false,
                    state.destination?.route?.float == nil {
                    state.alert = Alert.notice("配信停止中です。")
                } else if state.destination?.locations?.floats.isEmpty ?? false {
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
                case .locations(let festival):
                    state.destination = .locations(
                        PublicLocations.State(
                            festival,
                            mapRegion: state.$mapRegion
                        )
                    )
                    return .none
                case .route(let district):
                    return routeEffect(district)
                }
            case .routePrepared(let district, let routeId):
                state.isLoading = false
                state.destination = .route(
                    PublicRoute.State(
                        district,
                        routeId: routeId,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .errorCaught(let error):
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
    
    func routeEffect(_ district: District) -> Effect<Action> {
        .run { send in
            let result = await task({ try await sceneDataFetcher.launchDistrict(districtId: district.id) }, defaultError: APIError.unknown(message: "予期しないエラーが発生しました。"))
            switch result {
            case .success(let routeId):
                await send(.routePrepared(district, routeId))
            case .failure(let error):
                await send(.errorCaught(error))
            }
        }
    }
}

extension PublicMap.Destination.State: Equatable {}
extension PublicMap.Destination.Action: Equatable {}

extension PublicMap.Content: Identifiable, Hashable  {
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

extension PublicMap.State {
    init(festival: Festival, district: District, routeId: Route.ID?) {
        let districts: [District] = FetchAll(District.where{ $0.festivalId == festival.id }).wrappedValue
        let locations: PublicMap.Content = .locations(festival)
        let contents = [locations]
            + districts.prioritizing(districtId: district.id)
            .map{ PublicMap.Content.route($0) }
            
        let selected = contents[1]
        self.contents = contents
        self.selectedContent = selected
        
//        let mapRegion = Shared(value: makeRegion(route: current, location: location, origin: selected.origin, spanDelta: spanDelta))
        let mapRegion = Shared(value: makeRegion(origin: .init(latitude: 0, longitude: 0), spanDelta: spanDelta))
        self._mapRegion = mapRegion
        self.destination = .route(
            PublicRoute.State(
                district,
                routeId: routeId,
                mapRegion: mapRegion
            )
        )
    }
    
    init(
        festival: Festival
    ){
        let districts = FetchAll(District.where{ $0.festivalId == festival.id }).wrappedValue
        let selected: PublicMap.Content = .locations(festival)
        let contents = [selected] + districts.sorted().map{ PublicMap.Content.route($0) }
        
        self.contents = contents
        self.selectedContent = selected
        
//        let mapRegion = Shared(value: makeRegion(locations: locations, origin: festival.base)) FIXME
        let mapRegion = Shared(value: makeRegion(origin: .init(latitude: 0, longitude: 0), spanDelta: spanDelta))
        self._mapRegion = mapRegion
        self.destination = .locations(
            PublicLocations.State(
                festival,
                mapRegion: mapRegion
            )
        )
    }
}
