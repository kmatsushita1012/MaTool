//
//  PublicRouteFeature.swift
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
        @Shared var mapRegion: MKCoordinateRegion
        var replay: Replay

        // Navigation
        var detail: Detail?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case selected(RouteEntry)
        case pointTapped(PointEntry)
        case locationTapped(FloatEntry)
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(VoidAppResult)
        case locationReceived(VoidAppResult)
        case userLocationReceived(Coordinate)
        case userLocationFailed(String)
        case toastRequested(MapToast)
        case replayTapped
        case replayEnded
        case didSeek(Double)
    }

    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(LocationDataFetcherKey.self) var locationDataFetcher

    var body: some ReducerOf<PublicRouteFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .selected(let entry):
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
                return .task(Action.locationReceived) { [state] in
                    try await locationDataFetcher.fetch(districtId: state.district.id)
                }
            case .routeReceived(.success):
                state.replay = .initial(state.selected?.id)
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map(\.coordinate)) }
                return .none
            case .routeReceived(.failure(let error)):
                return .send(.toastRequested(.error(error, title: "ルートを取得できませんでした")))
            case .locationReceived(.success):
                if let coordinate = state.float?.floatLocation.coordinate {
                    state.$mapRegion.withLock{ $0 = makeRegion(origin: coordinate, spanDelta: spanDelta) }
                    return .none
                } else {
                    return .send(.toastRequested(.error("屋台位置を表示できませんでした。", title: "屋台位置の表示に失敗しました")))
                }
            case .locationReceived(.failure(let error)):
                if case .be(.notFound) = error {
                    return .send(.toastRequested(.notice("現在、屋台位置は配信されていません。")))
                } else if case .be(.forbidden) = error {
                    return .send(.toastRequested(.notice("現在、屋台位置は配信されていません。")))
                } else {
                    return .send(.toastRequested(.error(error, title: "屋台位置を取得できませんでした")))
                }
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
                    let result = await mapLocationProvider.getLocation()
                    switch result {
                    case .success(let location):
                        await send(.userLocationReceived(Coordinate.fromCL(location.coordinate)))
                    case .failure(let error):
                        await send(.userLocationFailed(error.asAppError.message))
                    case .loading:
                        await send(.userLocationFailed("現在地を取得できませんでした。"))
                    }
                }
            case .userLocationFailed(let message):
                return .send(.toastRequested(.error(message, title: "現在地を取得できませんでした")))
            case .toastRequested:
                return .none
            case .didSeek(let value):
                if state.replay.isRunning {
                    state.replay = .seek(value)
                }
                return .none
            case .replayEnded:
                state.replay = .stop
                return .none
            }
        }
    }
}

extension PublicRouteFeature.State {
    var hasDisplayableContent: Bool {
        !routes.isEmpty || float != nil
    }
    
    init(
        _ district: District,
        routeId: Route.ID?,
        mapRegion: Shared<MKCoordinateRegion>
    ) {
        self._mapRegion = mapRegion
        self._district = FetchOne(district)
        let routeQuery: FetchAll<RouteEntry> = .init(districtId: district.id, latest: true)
        self._routes = routeQuery
        // 存在しなければ先頭要素で代替
        let selected = routeQuery.wrappedValue.first { $0.route.id == routeId } ?? routeQuery.wrappedValue.first
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
        }.sorted()
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
