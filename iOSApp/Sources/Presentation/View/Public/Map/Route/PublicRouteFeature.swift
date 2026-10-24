//
//  PublicRouteFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import Foundation
import MapKit
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
        struct Float: Equatable {
            let district: District
            let location: FloatLocation
        }
        
        let districtId: District.ID
        @Shared fileprivate var appState: AppState?
        var isRouteLoading: Bool = false
        var district: District {
            appState!.festivalState.districts.first { $0.id == districtId }!
        }
        var routes: [RouteEntry] {
            guard let appState,
                  let districtState = appState.districtState,
                  districtState.districtId == districtId else { return [] }
            let periodsById = Dictionary(uniqueKeysWithValues: appState.festivalState.periods.map { ($0.id, $0) })
            return districtState.routes.compactMap { route in
                guard let period = periodsById[route.periodId] else { return nil }
                return RouteEntry(period: period, route: route)
            }.sorted()
        }
        var periods: [Period] {
            appState?.festivalState.periods ?? []
        }
        var selectedRouteId: Route.ID?
        var selected: RouteEntry? {
            routes.first { $0.id == selectedRouteId }
        }
        var points: [PointEntry] {
            guard let appState,
                  let districtState = appState.districtState,
                  districtState.districtId == districtId,
                  let selectedRouteId,
                  let routeState = appState.routeState,
                  routeState.route.id == selectedRouteId else { return [] }
            return routeState.points.sorted().map { point in
                PointEntry(
                    point,
                    checkpoint: appState.festivalState.checkpoints.first { $0.id == point.checkpointId },
                    performance: districtState.performances.first { $0.id == point.performanceId }
                )
            }
        }
        var float: FloatEntry? {
            guard let appState,
                  let location = appState.festivalState.floatLocations.first(where: { $0.districtId == districtId }),
                  let district = appState.festivalState.districts.first(where: { $0.id == districtId }) else { return nil }
            return FloatEntry(floatLocation: location, district: district)
        }
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
        case routeLoaded(AppResult<RoutePack?>)
        case pointTapped(PointEntry)
        case locationTapped(FloatEntry)
        case userFocusTapped
        case floatFocusTapped
        case userLocationReceived(Coordinate)
        case userLocationFailed(String)
        case toastDismissed
        case replayTapped
        case replayEnded
        case didSeek(Double)
    }

    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(LoadRouteStateUseCaseKey.self) var loadRouteStateUseCase
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    var body: some ReducerOf<PublicRouteFeature> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                var effects: [Effect<Action>] = []
                if state.toast == nil, let toast = state.initialToast(now: now) {
                    state.$toast.withLock { $0 = toast }
                }
                if state.toast != nil {
                    effects.append(toastDismissEffect())
                }
                if let routeId = state.selectedRouteId {
                    state.isRouteLoading = true
                    effects.append(loadRouteEffect(routeId: routeId, appState: state.$appState))
                }
                return .merge(effects)
            case .binding:
                return .none
            case .selected(let entry):
                state.$toast.withLock { $0 = nil }
                state.selectedRouteId = entry.id
                state.replay = .initial(entry.id)
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map(\.coordinate)) }
                state.isRouteLoading = true
                return .merge(
                    .cancel(id: CancelID.toastDismissal),
                    loadRouteEffect(routeId: entry.id, appState: state.$appState)
                )
            case .routeLoaded(.success(let pack)):
                state.isRouteLoading = false
                guard let pack else { return .none }
                guard pack.route.id == state.selectedRouteId else { return .none }
                state.$mapRegion.withLock { $0 = makeRegion(state.points.map(\.coordinate)) }
                return .none
            case .routeLoaded(.failure(let error)):
                state.isRouteLoading = false
                state.$toast.withLock { $0 = .error(error.message, title: "ルートを取得できませんでした") }
                return toastDismissEffect()
            case .pointTapped(let value):
                state.detail = .point(value)
                return .none
            case .locationTapped:
                guard let float = state.float else { return .none }
                state.detail = .location(float)
                return .none
            case .floatFocusTapped:
                if let coordinate = state.float?.floatLocation.coordinate {
                    state.$mapRegion.withLock{ $0 = makeRegion(origin: coordinate, spanDelta: spanDelta) }
                    return .none
                }
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

    private func loadRouteEffect(routeId: Route.ID, appState: Shared<AppState?>) -> Effect<Action> {
        .task(Action.routeLoaded) {
            try await loadRouteStateUseCase(routeId: routeId, appState: appState)
        }
    }
}

extension PublicRouteFeature.State {
    var hasDisplayableContent: Bool {
        !routes.isEmpty || float != nil
    }
    
    init(
        districtId: District.ID,
        routeId: Route.ID?,
        appState: Shared<AppState?>,
        mapRegion: Shared<MKCoordinateRegion>,
        toast: Shared<MapToast?>
    ) {
        self.districtId = districtId
        self._appState = appState
        self.selectedRouteId = routeId
        self._mapRegion = mapRegion
        self._toast = toast
        self.replay = .initial(routeId)
        let current = appState.wrappedValue
        let district = current?.festivalState.districts.first { $0.id == districtId }
        let points = current?.routeState.flatMap { $0.route.id == routeId ? $0.points : nil } ?? []
        let location = current?.festivalState.floatLocations.first { $0.districtId == districtId }
        if let mapRegion = makeRegion(points: points, location: location, origin: district?.base, spanDelta: spanDelta) {
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
