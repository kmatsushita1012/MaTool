//
//  PublicRoute.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import Foundation
import MapKit
import SQLiteData
import Shared

@Reducer
struct PublicRoute {

    @CasePathable
    enum Detail: Equatable {
        case point(Point)
        case location(FloatLocation)
    }

    @CasePathable
    enum Replay: Equatable {
        case initial
        case start
        case seek(Double)
        case stop
    }

    @ObservableState
    struct State: Equatable {
        @Selection struct Float: Equatable {
            let district: District
            let location: FloatLocation
        }
        
        @FetchOne var district: District
        @FetchAll var routes: [Route]

        var selected: Route?
        @FetchAll var points: [Point]

        @FetchOne var location: FloatLocation? {
            mutating didSet {
                if let location {
                    floatAnnotation = FloatCurrentAnnotation(district.name, location: location)
                } else {
                    floatAnnotation = nil
                }
            }
        }
        var floatAnnotation: FloatCurrentAnnotation?
        var isMenuExpanded: Bool = false
        @Shared var mapRegion: MKCoordinateRegion
        var replay: Replay = .initial

        // Navigation
        var detail: Detail?
        @Presents var alert: Alert.State?

        init(
            _ district: District,
            routeId: Route.ID?,
            mapRegion: Shared<MKCoordinateRegion>
        ) {
            self._mapRegion = mapRegion
            self._district = FetchOne(wrappedValue: district)
            self._routes = FetchAll(Route.where { $0.districtId == district.id })
            self.selected = routes.first { $0.id == routeId }
            self._points = FetchAll(Point.where { $0.routeId == selected?.id })
            self._location = FetchOne(FloatLocation.where{ $0.districtId == district.id } )
            if let location {
                floatAnnotation = FloatCurrentAnnotation(district.name, location: location)
            }
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case menuTapped
        case selected(Route)
        case pointTapped(Point)
        case locationTapped
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(VoidResult<APIError>)
        case locationReceived(VoidResult<APIError>)
        case userLocationReceived(Coordinate)
        case replayTapped
        case replayEnded
        case didSeek(Double)
        case alert(PresentationAction<Alert.Action>)
    }

    @Dependency(\.locationProvider) var locationProvider
    @Dependency(RouteDataFetcherKey.self) var dataFetcher

    var body: some ReducerOf<PublicRoute> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .menuTapped:
                state.isMenuExpanded = true
                return .none
            case .selected(let route):
                state.isMenuExpanded = false
                state.selected = route
                return .run { send in
                    let result = await task { try await dataFetcher.fetch(routeID: route.id) }
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
                return .none
            // TODO:
            //                return .run {[districtId = state.district.id] send in
            //                    let result = await apiRepository.getLocation(districtId)
            //                    await send(.locationReceived(result))
            //                }
            case .routeReceived(.success):
                state.replay = .initial
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map { $0.coordinate }) }
                return .none
            case .routeReceived(.failure(let error)):
                state.alert = Alert.error(error.localizedDescription)
                return .none
            case .locationReceived(.success):
                // locationは別の方法で設定される必要があります
                // TODO: locationの取得と設定を実装
                return .none
            case .locationReceived(.failure(let error)):
                if case .notFound = error {
                    state.alert = Alert.notice("現在地の配信は停止中です。")
                } else if case .forbidden = error {
                    state.alert = Alert.notice("現在地の配信は停止中です。")
                } else {
                    state.alert = Alert.error(error.localizedDescription)
                }P
                return .none
            case .replayTapped:
                if state.replay.isRunning {
                    state.replay = .stop
                } else {
                    state.replay = .start
                }
                return .none
            case .userLocationReceived(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value, spanDelta: spanDelta) }
                return .none
            case .userFocusTapped:
                return .run { send in
                    let result = await locationProvider.getLocation()
                    guard let coordinate = result.value?.coordinate else { return }
                    await send(.userLocationReceived(Coordinate.fromCL(coordinate)))
                }
            case .didSeek(let value):
                if state.replay.isRunning {
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

    var others: [Route] {
        routes.filter {
            if let selected {
                $0.id != selected.id
            } else {
                false
            }
        }
    }

    var isReplayEnable: Bool {
        selected != nil
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
        switch self {
        case .point(let item):
            return item.id
        case .location(let item):
            return item.id
        }
    }
}
