//
//  PublicLocationsFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/04.
//

import ComposableArchitecture
import Fallback
import MapKit
import Shared

@Reducer
struct PublicLocationsFeature {
    private enum CancelID {
        case toastDismissal
    }

    @ObservableState
    struct State:Equatable {

        let festivalId: Festival.ID
        @Shared fileprivate var appState: AppState?

        @Fallback(\PublicLocationsFeature.State.appState?.festivalState.festival)
        @ObservationStateIgnored
        var festival: Festival

        var floats: [FloatEntry] {
            guard let festivalState = appState?.festivalState else { return [] }
            return festivalState.floatLocations.compactMap { location in
                guard let district = festivalState.districts.first(where: { $0.id == location.districtId }) else {
                    return nil
                }
                return FloatEntry(floatLocation: location, district: district)
            }
        }
        
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
        case reloadReceived(AppResult<[FloatLocation]>)
    }
    
    @Dependency(\.mapLocationProvider) var mapLocationProvider
    @Dependency(\.continuousClock) var clock
    @Dependency(FetchLocationUseCaseKey.self) var fetchLocationUseCase
    
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
                return .task(Action.reloadReceived) { [festivalId = state.festivalId, appState = state.$appState] in
                    try await fetchLocationUseCase(festivalId: festivalId, appState: appState)
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
            case .reloadReceived(.success):
                return .none
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
        festivalId: Festival.ID,
        festival: Festival,
        appState: Shared<AppState?>,
        mapRegion: Shared<MKCoordinateRegion>,
        toast: Shared<MapToast?>
    ){
        self.festivalId = festivalId
        self._appState = appState
        self._festival = festival
        self._mapRegion = mapRegion
        self._toast = toast
        if appState.wrappedValue?.festivalState.floatLocations.isEmpty ?? true {
            self.$toast.withLock { $0 = .notice("現在、配信中の情報はありません。") }
        }
    }
}
