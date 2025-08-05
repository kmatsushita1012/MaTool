//
//  RouteInfo.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/04.
//

import Foundation
import ComposableArchitecture
import MapKit

@Reducer
struct PublicRoute {
    
    @CasePathable
    enum Detail: Equatable{
        case point(Point)
        case location(LocationInfo)
    }
    
    @ObservableState
    struct State: Equatable {
        let id: String
        let items: [RouteSummary]?
        var selectedItem: RouteSummary?
        var route: RouteInfo?
        var location: LocationInfo?
        var isMenuExpanded: Bool = false
        @Shared var mapRegion: MKCoordinateRegion
        var detail: Detail?
        
        var points: [Point]? {
            if let route {
                PointFilter.pub.apply(to: route)
            } else {
                nil
            }
        }
        
        var segments: [Segment]? {
            route?.segments
        }
        
        var others: [RouteSummary]? {
            items?.filter {
                if let selectedItem {
                    $0.id != selectedItem.id
                } else {
                    false
                }
            }
        }
        
        init(id: String, routes: [RouteSummary]? = nil, selectedRoute: RouteInfo? = nil, location: LocationInfo? = nil, mapRegion: Shared<MKCoordinateRegion>){
            self.id = id
            self.items = routes
            if let selectedRoute {
                self.selectedItem = RouteSummary(from: selectedRoute)
            }
            self.route = selectedRoute
            self.location = location
            self._mapRegion = mapRegion
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case menuTapped
        case itemSelected(RouteSummary)
        case pointTapped(Point)
        case reloadTapped
        case locationTapped
        case routeReceived(Result<RouteInfo, ApiError>)
        case locationReceived(Result<LocationInfo, ApiError>)
    }
    
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(\.authService) var authService
    
    var body: some ReducerOf<PublicRoute> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding(_):
                return .none
            case .menuTapped:
                state.isMenuExpanded = true
                return .none
            case .itemSelected(let value):
                state.isMenuExpanded = false
                state.selectedItem = value
                return .run { send in
                    let accessToken = await authService.getAccessToken()
                    let result = await apiRepository.getRoute(value.id, accessToken)
                    await send(.routeReceived(result))
                }
            case .pointTapped(let value):
                state.detail = .point(value)
                return .none
            case .locationTapped:
                guard let location = state.location else { return .none }
                state.detail = .location(location)
                return .none
            case .reloadTapped:
                return .run {[id = state.id] send in
                    let accessToken = await authService.getAccessToken()
                    let result = await apiRepository.getLocation(id, accessToken)
                    await send(.locationReceived(result))
                }
            case .routeReceived(.success(let value)):
                state.route = value
                state.$mapRegion.withLock { $0 = makeRegion(value.points.map{ $0.coordinate })}
                return .none
            case .routeReceived(.failure(let error)):
                return .none
            case .locationReceived(.success(let value)):
                state.location = value
                return .none
            case .locationReceived(.failure(let error)):
                return .none
            }
        }
    }
}

extension PublicRoute.Detail: Identifiable {
    var id: String {
        switch self{
        case .point(let item):
            return item.id
        case .location(let item):
            return item.id
        }
    }
}
