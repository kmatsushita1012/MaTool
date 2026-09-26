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

    private enum CancelID {
        case toastDismissal
    }

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
        @FetchAll var periods: [Period]

        var selected: RouteEntry? {
            didSet {
                self._points = FetchAll(routeId: selected?.id)
            }
        }
        @FetchAll var points: [PointEntry]

        @FetchOne var float: FloatEntry?
        @Shared var mapRegion: MKCoordinateRegion
        @Shared var toast: MapToast?
        var replay: Replay

        // Navigation
        var detail: Detail?
    }

    @CasePathable
    enum Action: Equatable, BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case selected(RouteEntry)
        case pointTapped(PointEntry)
        case locationTapped(FloatEntry)
        case userFocusTapped
        case floatFocusTapped
        case routeReceived(VoidAppResult)
        case floatLocationReceived(VoidAppResult)
        case userLocationReceived(Coordinate)
        case userLocationFailed(String)
        case toastDismissed
        case replayTapped
        case replayEnded
        case didSeek(Double)
    }

    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now
    @Dependency(RouteDataFetcherKey.self) var dataFetcher
    @Dependency(LocationDataFetcherKey.self) var locationDataFetcher

    var body: some ReducerOf<PublicRouteFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.toast == nil, let toast = state.initialToast(now: now) {
                    state.$toast.withLock { $0 = toast }
                }
                guard state.toast != nil else { return .none }
                return toastDismissEffect()
            case .binding:
                return .none
            case .selected(let entry):
                state.$toast.withLock { $0 = nil }
                state.selected = entry
                return .merge(
                    .cancel(id: CancelID.toastDismissal),
                    .task(Action.routeReceived) {
                        try await dataFetcher.fetch(routeID: entry.route.id)
                    }
                )
            case .pointTapped(let value):
                state.detail = .point(value)
                return .none
            case .locationTapped:
                guard let float = state.float else { return .none }
                state.detail = .location(float)
                return .none
            case .floatFocusTapped:
                return .task(Action.floatLocationReceived) { [state] in
                    try await locationDataFetcher.fetch(districtId: state.district.id)
                }
            case .routeReceived(.success):
                state.replay = .initial(state.selected?.id)
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map(\.coordinate)) }
                return .none
            case .routeReceived(.failure(let error)):
                state.$toast.withLock { $0 = .error(error, title: "ルートを取得できませんでした") }
                return toastDismissEffect()
            case .floatLocationReceived(.success):
                if let coordinate = state.float?.floatLocation.coordinate {
                    state.$mapRegion.withLock{ $0 = makeRegion(origin: coordinate, spanDelta: spanDelta) }
                    return .none
                }
                state.$toast.withLock { $0 = state.locationUnavailableToast }
                return toastDismissEffect()
            case .floatLocationReceived(.failure):
                state.$toast.withLock { $0 = state.locationUnavailableToast }
                return toastDismissEffect()
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
                state.$toast.withLock { $0 = .error(message, title: "現在地を取得できませんでした") }
                return toastDismissEffect()
            case .toastDismissed:
                state.$toast.withLock { $0 = nil }
                return .cancel(id: CancelID.toastDismissal)
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

    private func toastDismissEffect() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: .seconds(3))
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toastDismissal, cancelInFlight: true)
    }
}

extension PublicRouteFeature.State {
    var hasDisplayableContent: Bool {
        !routes.isEmpty || float != nil
    }
    
    init(
        _ district: District,
        routeId: Route.ID?,
        mapRegion: Shared<MKCoordinateRegion>,
        toast: Shared<MapToast?>
    ) {
        self._mapRegion = mapRegion
        self._toast = toast
        self._district = FetchOne(district)
        let routeQuery: FetchAll<RouteEntry> = .init(districtId: district.id, latest: true)
        self._routes = routeQuery
        let allPeriods = FetchAll<Period>(
            Period.where { $0.festivalId.eq(district.festivalId) }
        ).wrappedValue
        let latestYear = allPeriods.map(\.date.year).max() ?? SimpleDate.now.year
        self._periods = FetchAll(
            Period.where {
                $0.festivalId.eq(district.festivalId) && $0.date.inYear(latestYear)
            }
        )
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

    fileprivate func initialToast(now: Date) -> MapToast? {
        if routes.isEmpty {
            return .notice("\(district.name)は経路配信を停止しています")
        }
        return currentLocationToast(now: now)
    }

    fileprivate func currentLocationToast(now: Date) -> MapToast? {
        guard float == nil, periods.contains(where: { $0.contains(now) }) else {
            return nil
        }
        return locationUnavailableToast
    }

    fileprivate var locationUnavailableToast: MapToast {
        .notice("\(district.name)は位置配信を停止しています")
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
