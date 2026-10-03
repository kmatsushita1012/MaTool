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
    private enum CancelID {
        case districtLaunch
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
        @Shared var toast: MapToast?
    }
    
    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case dismissTapped
        case contentSelected(Content)
        case districtContentEvaluated(District, Bool)
        case districtLaunchReceived(District, AppResult<Route.ID?>)
        case errorCaught(AppError)
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
                state.$toast.withLock { $0 = nil }
                state.selectedContent = value
                state.isLoading = false
                switch value {
                case .locations(let festival):
                    state.destination = .locations(
                        PublicLocationsFeature.State(
                            festival,
                            mapRegion: state.$mapRegion,
                            toast: state.$toast
                        )
                    )
                    return .cancel(id: CancelID.districtLaunch)
                case .route(let district):
                    state.isLoading = true
                    return districtLaunchEffect(
                        district: district,
                        periodId: state.currentPeriodId
                    )
                }
            case .districtLaunchReceived(let district, .success(let routeId)):
                guard PublicMapFeature.isSelected(district, by: state.selectedContent) else { return .none }
                state.isLoading = false
                if let routeId,
                   let route = FetchOne(Route.find(routeId)).wrappedValue {
                    state.currentPeriodId = route.periodId
                }
                state.destination = .route(
                    PublicRouteFeature.State(
                        district,
                        routeId: routeId,
                        mapRegion: state.$mapRegion,
                        toast: state.$toast
                    )
                )
                let hasDisplayableContent = state.destination?.route?.hasDisplayableContent ?? false
                return .send(.districtContentEvaluated(district, hasDisplayableContent))
            case .districtLaunchReceived(let district, .failure(let error)):
                guard PublicMapFeature.isSelected(district, by: state.selectedContent) else { return .none }
                state.isLoading = false
                state.$toast.withLock { $0 = .error(error, title: "地区情報を取得できませんでした") }
                return .none
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
        case .destination(.presented(.route(.selected(let entry)))):
            state.currentPeriodId = entry.period.id
            return .none
        default:
            return .none
        }
    }
    
    func districtLaunchEffect(
        district: District,
        periodId: Period.ID?
    ) -> Effect<Action> {
        .task({ result in Action.districtLaunchReceived(district, result) }) {
            try await publicMapAdUsecase.handleDistrictSelection(
                districtId: district.id,
                periodId: periodId
            )
        }
        .cancellable(id: CancelID.districtLaunch, cancelInFlight: true)
    }
}

extension PublicMapFeature {
    static func isSelected(_ district: District, by content: Content) -> Bool {
        guard case .route(let selectedDistrict) = content else { return false }
        return selectedDistrict.id == district.id
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
        self._toast = Shared(value: nil)
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
                mapRegion: $mapRegion,
                toast: $toast
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
        self._toast = Shared(value: nil)
        
        self._mapRegion = Shared(value: makeRegion(origin: festival.base, spanDelta: spanDelta))
        self.destination = .locations(
            PublicLocationsFeature.State(
                festival,
                mapRegion: $mapRegion,
                toast: $toast
            )
        )
    }
}
