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
        let contents: [Content]
        var selectedContent: Content
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
        case errorCaught(APIError)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<AlertFeature.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(SceneDataFetcherKey.self) var sceneDataFetcher
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
                    return routeEffect(district)
                }
            case .routePrepared(let district, let routeId):
                state.isLoading = false
                state.destination = .route(
                    PublicRouteFeature.State(
                        district,
                        routeId: routeId,
                        mapRegion: state.$mapRegion
                    )
                )
                return .none
            case .errorCaught(let error):
                state.alert = AlertFeature.error(error.localizedDescription)
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
    init(festival: Festival, district: District, routeId: Route.ID?) {
        let districts: [District] = FetchAll(District.where{ $0.festivalId.eq(festival.id) }).wrappedValue
        let locations: PublicMapFeature.Content = .locations(festival)
        let contents = [locations]
            + districts.prioritizing(districtId: district.id)
            .map{ PublicMapFeature.Content.route($0) }
            
        let selected = contents[1]
        self.contents = contents
        self.selectedContent = selected
        
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
        festival: Festival
    ){
        let districts = FetchAll(District.where{ $0.festivalId.eq(festival.id) }).wrappedValue
        let selected: PublicMapFeature.Content = .locations(festival)
        let contents = [selected] + districts.sorted().map{ PublicMapFeature.Content.route($0) }
        
        self.contents = contents
        self.selectedContent = selected
        
        self._mapRegion = Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta))
        self.destination = .locations(
            PublicLocationsFeature.State(
                festival,
                mapRegion: $mapRegion
            )
        )
    }
}
