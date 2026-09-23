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
    @ObservableState
    struct State:Equatable {

        let festival: Festival
        @FetchAll var floats: [FloatEntry]
        
        @Shared var mapRegion: MKCoordinateRegion
        var detail: FloatEntry?
        var toast: MapToast?
    }
    
    @CasePathable
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case floatTapped(FloatEntry)
        case floatFocusSelected(FloatEntry)
        case userFocusTapped
        case userLocationReceived(Coordinate)
        case userLocationFailed(String)
        case reloadTapped
        case reloadReceived(VoidAppResult)
        case toastDismissed
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(LocationDataFetcherKey.self) var dataFetcher
    
    var body: some ReducerOf<PublicLocationsFeature> {
        BindingReducer()
        Reduce{ state, action in
            switch action {
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
                state.toast = .error(error, title: "現在地一覧を更新できませんでした")
                return .none
            case .userLocationFailed(let message):
                state.toast = .error(message, title: "現在地を取得できませんでした")
                return .none
            case .toastDismissed:
                state.toast = nil
                return .none
            default:
                return .none
            }
        }
    }
}

extension PublicLocationsFeature.State {
    init(_ festival: Festival, mapRegion: Shared<MKCoordinateRegion>){
        self.festival = festival
        self._floats = FetchAll(festivalId: festival.id)
        self._mapRegion = mapRegion
        if !self.floats.isEmpty {
            self.$mapRegion.withLock{ $0 = makeRegion(locations: floats.map(keyPath: \.floatLocation), origin: festival.base) }
        }
    }
}
