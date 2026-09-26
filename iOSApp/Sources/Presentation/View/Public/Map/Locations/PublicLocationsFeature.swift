//
//  PublicLocationsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import MapKit
import Shared
import SQLiteData

@Reducer
struct PublicLocationsFeature {
    private enum CancelID {
        case toastDismissal
    }

    @ObservableState
    struct State:Equatable {

        let festival: Festival
        @FetchAll var floats: [FloatEntry]
        
        @Shared var mapRegion: MKCoordinateRegion
        @Shared var toast: MapToast?
        var detail: FloatEntry?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case floatTapped(FloatEntry)
        case floatFocusSelected(FloatEntry)
        case userFocusTapped
        case userLocationReceived(Coordinate)
        case userLocationFailed(String)
        case toastDismissed
        case reloadTapped
        case reloadReceived(VoidAppResult)
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(\.continuousClock) var clock
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<PublicLocationsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
            case .onAppear:
                guard state.toast != nil else { return .none }
                return toastDismissEffect()
            case .binding(_):
                return .none
            case .floatTapped(let entry):
                state.detail = entry
                return .none
            case .floatFocusSelected(let entry):
                state.$mapRegion.withLock { $0 = makeRegion(origin: entry.floatLocation.coordinate, spanDelta: spanDelta)}
                return .none
            case .reloadTapped:
                return .task(Action.reloadReceived) { [state] in
                    try await dataFetcher.fetchAll(festivalId: state.festival.id)
                }
            case .userLocationReceived(let value):
                state.$mapRegion.withLock { $0 = makeRegion(origin: value, spanDelta: spanDelta)}
                return .none
            case .userFocusTapped:
                return .run{ send in
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
            case .reloadReceived(.failure(let error)):
                state.$toast.withLock { $0 = .error(error, title: "現在地一覧を更新できませんでした") }
                return toastDismissEffect()
            case .userLocationFailed(let message):
                state.$toast.withLock { $0 = .error(message, title: "現在地を取得できませんでした") }
                return toastDismissEffect()
            case .toastDismissed:
                state.$toast.withLock { $0 = nil }
                return .cancel(id: CancelID.toastDismissal)
            default:
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

extension PublicLocationsFeature.State {
    init(
        _ festival: Festival,
        mapRegion: Shared<MKCoordinateRegion>,
        toast: Shared<MapToast?>
    ){
        self.festival = festival
        self._floats = FetchAll(festivalId: festival.id)
        self._mapRegion = mapRegion
        self._toast = toast
        if !self.floats.isEmpty {
            self.$mapRegion.withLock{ $0 = makeRegion(locations: floats.map(keyPath: \.floatLocation), origin: festival.base) }
        } else {
            self.$toast.withLock { $0 = .notice("現在、配信中の情報はありません。") }
        }
    }
}
