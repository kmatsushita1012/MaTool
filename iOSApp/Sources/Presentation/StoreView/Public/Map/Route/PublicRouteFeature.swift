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
struct PublicRouteFeature {

    @CasePathable
    enum Detail: Equatable {
        case point(PointEntry)
        case location(FloatEntry)
    }

    @CasePathable
    enum Replay: Equatable {
        case initial(Route.ID?)
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
        @FetchAll var routes: [RouteEntry]

        var selected: RouteEntry? {
            didSet {
                self._points = FetchAll(routeId: selected?.id)
            }
        }
        @FetchAll var points: [PointEntry]

        @FetchOne var float: FloatEntry?
        var isMenuExpanded: Bool = false
        @Shared var mapRegion: MKCoordinateRegion
        var replay: Replay

        // Navigation
        var detail: Detail?
        @Presents var alert: AlertFeature.State?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case menuTapped
        case selected(RouteEntry)
        case pointTapped(PointEntry)
        case locationTapped(FloatEntry)
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(VoidTaskResult)
        case locationReceived(VoidTaskResult)
        case userLocationReceived(Coordinate)
        case replayTapped
        case replayEnded
        case didSeek(Double)
        case alert(PresentationAction<AlertFeature.Action>)
    }

    @Dependency(\.locationProvider) var locationProvider
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(LocationDataFetcherKey.self) var locationDataFetcher

    var body: some ReducerOf<PublicRouteFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .menuTapped:
                state.isMenuExpanded = true
                return .none
            case .selected(let entry):
                state.isMenuExpanded = false
                state.selected = entry
                return .task(Action.routeReceived) {
                    try await dataFetcher.fetch(routeID: entry.route.id)
                }
            case .pointTapped(let value):
                state.detail = .point(value)
                return .none
            case .locationTapped:
                guard let float = state.float else { return .none }
                state.detail = .location(float)
                return .none
            case .floatFocusTapped:
                return .run {[districtId = state.district.id] send in
                    try? await locationDataFetcher.fetch(districtId: districtId)
                }
            case .routeReceived(.success):
                state.replay = .initial(state.selected?.id)
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map(\.coordinate)) }
                return .none
            case .routeReceived(.failure(let error)):
                state.alert = AlertFeature.error(error.localizedDescription)
                return .none
            case .locationReceived(.failure(let error)):
                if let error = error as? APIError,
                    case .notFound = error {
                    state.alert = AlertFeature.notice("現在地の配信は停止中です。")
                } else if let error = error as? APIError,
                    case .forbidden = error {
                    state.alert = AlertFeature.notice("現在地の配信は停止中です。")
                } else {
                    state.alert = AlertFeature.error(error.localizedDescription)
                }
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
            default:
                return .none
            }
        }
    }
}

extension PublicRouteFeature.State {
    
    init(
        _ district: District,
        routeId: Route.ID?,
        mapRegion: Shared<MKCoordinateRegion>
    ) {
        self._mapRegion = mapRegion
        self._district = FetchOne(wrappedValue: district)
        let routeQuery: FetchAll<RouteEntry> = .init(districtId: district.id, latest: true)
        self._routes = routeQuery
        let selected = routeQuery.wrappedValue.first { $0.route.id == routeId }
        self.selected = selected
        self.replay = .initial(selected?.id)
        self._points = FetchAll(routeId: selected?.id)
        self._float = FetchOne(districtId: district.id)
        let points: [Point] = {
            if let routeId {
                FetchAll(routeId: routeId).wrappedValue
            } else {
                []
            }
        }()
        if let mapRegion = makeRegion(points: points, location: self.float?.floatLocation, origin: district.base, spanDelta: spanDelta) {
            self.$mapRegion.withLock{ $0 = mapRegion }
        }
    }

    var others: [RouteEntry] {
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

extension PublicRouteFeature.Replay {
    var isRunning: Bool {
        switch self {
        case .start, .seek:
            return true
        case .stop, .initial:
            return false
        }
    }
}

extension PublicRouteFeature.Detail: Identifiable {
    var id: String {
        switch self {
        case .point(let item):
            return item.id
        case .location(let item):
            return item.id
        }
    }
}
