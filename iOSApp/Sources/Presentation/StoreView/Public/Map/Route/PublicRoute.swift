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
        case point(PointViewState)
        case location(FloatViewState)
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
        let items: [CurrentResponse.RouteItem]?
        var selectedId: String?
        let checkpoints: [Checkpoint]
        let performances: [Performance]
        
        var route: Route? {
            didSet {
                points = .from(route, checkpoints: checkpoints, performances: performances)
            }
        }
        
        var points: [PointViewState]
        var location: FloatViewState? {
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
        var replay: Replay = .initial
        @Shared var mapRegion: MKCoordinateRegion
        
        var detail: Detail?
        @Presents var alert: Alert.State?
        
        
        init(
            _ response: CurrentResponse,
            mapRegion: Shared<MKCoordinateRegion>
        ){
            self.districtId = response.districtId
            self.name = response.districtName
            self.items = response.items
            self.selectedId = response.detail?.route.id
            self.route = response.detail?.route
            if let location = response.location {
                let viewState: FloatViewState = .init(location, districtName: name)
                self.location = viewState
                floatAnnotation = FloatCurrentAnnotation(viewState)
            }
            self._mapRegion = mapRegion
        }
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case menuTapped
        case itemSelected(CurrentResponse.RouteItem)
        case pointTapped(PointViewState)
        case locationTapped
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(Result<RouteResponse, APIError>)
        case locationReceived(Result<FloatViewState, APIError>)
        case userLocationReceived(Coordinate)
        case replayTapped
        case replayEnded
        case didSeek(Double)
        case alert(PresentationAction<Alert.Action>)
    }
    
    @Dependency(\.locationProvider) var locationProvider
    @Dependency(\.apiRepository) var apiRepository
    @Dependency(RouteRemoteRepositoryKey.self) var routeRepository
    
    var body: some ReducerOf<PublicRoute> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .menuTapped:
                state.isMenuExpanded = true
                return .none
            case .itemSelected(let value):
                state.isMenuExpanded = false
                guard let routeId = value.routeId else { return .none }
                state.selectedId = routeId
                return .run { send in
                    let result = await routeRepository.get(routeId: routeId)
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
                state.route = value.route
                state.replay = .initial
                state.$mapRegion.withLock { $0 = makeRegion(value.route.points.map{ $0.coordinate })}
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
            default:
                return .none
            }
        }
    }
}

extension PublicRoute.State {
    
    var others: [CurrentResponse.RouteItem]? {
        if let selectedId {
            items?.filter {
                $0.routeId != selectedId
            }
        } else {
            items
        }
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
