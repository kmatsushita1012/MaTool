//
//  PublicRoute.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import Foundation
import MapKit
import ComposableArchitecture
import Shared

@Reducer
struct PublicRoute {
    
    @CasePathable
    enum Detail: Equatable{
        case point(Point)
        case location(FloatLocationGetDTO)
    }
    
    @CasePathable
    enum Replay: Equatable{
        case initial
        case start
        case seek(Double)
        case stop
    }
    
    @ObservableState
    struct State: Equatable {
        let districtId: String
        let name: String
        let items: [RouteItem]?
        var selectedItem: RouteItem?
        var route: Route?
        var location: FloatLocationGetDTO? {
            didSet {
                if let location {
                    floatAnnotation = FloatCurrentAnnotation(location: location)
                } else {
                    floatAnnotation = nil
                }
            }
        }
        var floatAnnotation: FloatCurrentAnnotation?
        var isMenuExpanded: Bool = false
        @Shared var mapRegion: MKCoordinateRegion
        var detail: Detail?
        var replay: Replay = .initial
        @Presents var alert: Alert.State?
        
        init(
            districtId: String,
            name: String,
            routes: [RouteItem]? = nil,
            selectedRoute: Route? = nil,
            location: FloatLocationGetDTO? = nil,
            mapRegion: Shared<MKCoordinateRegion>
        ){
            self.districtId = districtId
            self.name = name
            self.items = routes
            if let selectedRoute {
                self.selectedItem = RouteItem(from: selectedRoute)
            }
            self.route = selectedRoute
            self.location = location
            if let location {
                floatAnnotation = FloatCurrentAnnotation(location: location)
            }
            self._mapRegion = mapRegion
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case menuTapped
        case itemSelected(RouteItem)
        case pointTapped(Point)
        case locationTapped
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(Result<Route, APIError>)
        case locationReceived(Result<FloatLocationGetDTO, APIError>)
        case userLocationReceived(Coordinate)
        case replayTapped
        case replayEnded
        case didSeek(Double)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(\.apiRepository) var apiRepository
    
    var body: some ReducerOf<PublicRoute> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .binding:
                return .none
            case .menuTapped:
                state.isMenuExpanded = true
                return .none
            case .itemSelected(let value):
                state.isMenuExpanded = false
                state.selectedItem = value
                return .run { send in
                    
                    let result = await apiRepository.getRoute(value.id)
                    await send(.routeReceived(result))
                }
            case .pointTapped(let value):
                state.detail = .point(value)
                return .none
            case .locationTapped:
                guard let location = state.location else { return .none }
                state.detail = .location(location)
                return .none
            case .floatFocusTapped:
                return .run {[districtId = state.districtId] send in
                    let result = await apiRepository.getLocation(districtId)
                    await send(.locationReceived(result))
                }
            case .routeReceived(.success(let value)):
                state.route = value
                state.replay = .initial
                state.$mapRegion.withLock { $0 = makeRegion(value.points.map{ $0.coordinate })}
                return .none
            case .routeReceived(.failure(let error)):
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .locationReceived(.success(let value)):
                state.location = value
                state.$mapRegion.withLock { $0 = makeRegion(origin: value.coordinate, spanDelta: spanDelta)}
                return .none
            case .locationReceived(.failure(.notFound)),
                .locationReceived(.failure(.forbidden)):
                state.alert = Alert.notice("現在地の配信は停止中です。")
                return .none
            case .locationReceived(.failure(let error)):
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .replayTapped:
                if state.replay.isRunning{
                    state.replay = .stop
                } else {
                    state.replay = .start
                }
                return .none
            case .userLocationReceived(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value, spanDelta: spanDelta)}
                return .none
            case .userFocusTapped:
                return .run{ send in
                    let result = await locationProvider.getLocation()
                    guard let coordinate = result.value?.coordinate  else { return }
                    await send(.userLocationReceived(Coordinate.fromCL(coordinate)))
                }
            case .didSeek(let value):
                if state.replay.isRunning{
                    state.replay = .seek(value)
                }
                return .none
            case .replayEnded:
                state.replay = .stop
                return .none
            case .alert:
                state.alert = nil
                return .none
            }
        }
    }
}

extension PublicRoute.State {
    var pinPoints: [Point]? {
        if let route {
            PointFilter.pub.apply(to: route)
        } else {
            nil
        }
    }
    
    var points: [Point]? {
        route?.points
    }
    
    var others: [RouteItem]? {
        items?.filter {
            if let selectedItem {
                $0.id != selectedItem.id
            } else {
                false
            }
        }.sorted()
    }
    
    var isReplayEnable: Bool {
        route != nil
    }
}

extension PublicRoute.Replay {
    var isRunning: Bool {
        switch self {
        case .start, .seek:
            return true
        case .stop, .initial:
            return false
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
