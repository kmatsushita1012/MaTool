//
//  LocationTrackingFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation
import Shared

enum LocationPermissionSheetMode: Equatable {
    case requestWhenInUseAndAlways
    case requestAlways
    case settings

    init?(
        authorizationStatus: CLAuthorizationStatus,
        hasRequestedAlwaysLocationPermission: Bool
    ) {
        switch authorizationStatus {
        case .notDetermined:
            self = .requestWhenInUseAndAlways
        case .authorizedWhenInUse:
            self = hasRequestedAlwaysLocationPermission ? .settings : .requestAlways
        case .denied, .restricted:
            self = .settings
        case .authorizedAlways:
            return nil
        @unknown default:
            self = .settings
        }
    }
}

@Reducer
struct LocationTrackingFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var isTracking: Bool
        var isLoading: Bool = false
        var history: [Status] = []
        var selectedInterval: Interval = Interval.sample
        let intervals = Interval.options
        var isLocationPermissionSheetPresented = false
        var locationPermissionSheetMode: LocationPermissionSheetMode?
        var shouldRequestLocationPermission = false
        var showsUserLocation = false
        var isAlwaysLocationAuthorized = false
        
        var isPickerEnabled: Bool {
            !isTracking
        }
    }
    
    @CasePathable
    enum Action:BindableAction, Equatable{
        case onAppear
        case binding(BindingAction<State>)
        case locationPermissionButtonTapped
        case locationPermissionStateRefreshed(LocationPermissionState)
        case locationPermissionButtonStateReceived(LocationPermissionState)
        case trackingStartResultReceived(LocationTrackingStartResult)
        case locationPermissionProceedTapped
        case locationPermissionSheetDismissed
        case historyUpdated([Status])
        case dismissTapped
    }
    
    @Dependency(\.locationUsecase) var locationUsecase
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<LocationTrackingFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                return .run { send in
                    let initial = await locationUsecase.getLocationHistory()
                    await send(.historyUpdated(initial))
                    // 以降の更新を購読
                    for await history in await locationUsecase.historyStream() {
                        await send(.historyUpdated(history))
                    }
                }
                .cancellable(id: "HistoryStream", cancelInFlight: true)
            case .locationPermissionButtonTapped:
                return .run { send in
                    await send(
                        .locationPermissionButtonStateReceived(
                            await locationUsecase.locationPermissionState()
                        )
                    )
                }
            case .locationPermissionStateRefreshed(let permissionState):
                state.showsUserLocation = permissionState.isLocationAuthorized
                state.isAlwaysLocationAuthorized = permissionState.isAlwaysAuthorized
                return .none
            case .locationPermissionButtonStateReceived(let permissionState):
                state.showsUserLocation = permissionState.isLocationAuthorized
                state.isAlwaysLocationAuthorized = permissionState.isAlwaysAuthorized
                let sheetMode = LocationPermissionSheetMode(
                    authorizationStatus: permissionState.authorizationStatus,
                    hasRequestedAlwaysLocationPermission: permissionState.hasRequestedAlwaysLocationPermission
                )
                state.locationPermissionSheetMode = sheetMode
                state.isLocationPermissionSheetPresented = sheetMode != nil
                return .none
            case .trackingStartResultReceived(.started(let permissionState)):
                state.showsUserLocation = permissionState.isLocationAuthorized
                state.isAlwaysLocationAuthorized = permissionState.isAlwaysAuthorized
                let id = state.id
                guard state.isTracking else {
                    return .run { _ in
                        await locationUsecase.stop(id: id)
                    }
                }
                return .none
            case .trackingStartResultReceived(.permissionRequired(let permissionState)):
                state.showsUserLocation = permissionState.isLocationAuthorized
                state.isAlwaysLocationAuthorized = permissionState.isAlwaysAuthorized
                guard state.isTracking else { return .none }
                state.isTracking = false
                let sheetMode = LocationPermissionSheetMode(
                    authorizationStatus: permissionState.authorizationStatus,
                    hasRequestedAlwaysLocationPermission: permissionState.hasRequestedAlwaysLocationPermission
                )
                state.locationPermissionSheetMode = sheetMode
                state.isLocationPermissionSheetPresented = sheetMode != nil
                return .none
            case .trackingStartResultReceived(.locationServicesDisabled):
                state.isTracking = false
                return .none
            case .locationPermissionProceedTapped:
                state.shouldRequestLocationPermission = true
                state.isLocationPermissionSheetPresented = false
                return .none
            case .locationPermissionSheetDismissed:
                let shouldRequest = state.shouldRequestLocationPermission
                let shouldRefresh = state.locationPermissionSheetMode == .settings
                state.shouldRequestLocationPermission = false
                return .run { send in
                    if shouldRequest {
                        await locationUsecase.requestPermission()
                    }
                    guard shouldRefresh else { return }
                    await send(.locationPermissionStateRefreshed(await locationUsecase.locationPermissionState()))
                }
            case .binding(\.isTracking):
                let id = state.id
                let isTracking = state.isTracking
                return .run { [
                    id,
                    isTracking,
                    interval = state.selectedInterval
                ] send in
                    await send(.locationPermissionStateRefreshed(await locationUsecase.locationPermissionState()))
                    if !isTracking {
                        await locationUsecase.stop(id: id)
                        return
                    }
                    let result = await locationUsecase.start(id: id, interval: interval)
                    await send(.trackingStartResultReceived(result))
                }
                .cancellable(id: "LocationTrackingStart", cancelInFlight: true)
            case .binding:
                return .none
            case .historyUpdated(let history):
                state.history = history
                return .none
            case .dismissTapped:
                return .dismiss
            }
        }
    }
}

extension LocationTrackingFeature.State {
    init(
        id: String,
        isTracking: Bool,
        selectedInterval: Interval,
        permissionState: LocationPermissionState
    ) {
        self.id = id
        self.isTracking = isTracking
        self.selectedInterval = selectedInterval
        let sheetMode = LocationPermissionSheetMode(
            authorizationStatus: permissionState.authorizationStatus,
            hasRequestedAlwaysLocationPermission: permissionState.hasRequestedAlwaysLocationPermission
        )
        self.locationPermissionSheetMode = sheetMode
        self.isLocationPermissionSheetPresented = sheetMode != nil
        self.showsUserLocation = permissionState.isLocationAuthorized
        self.isAlwaysLocationAuthorized = permissionState.isAlwaysAuthorized
    }
}


struct Interval: Equatable, Hashable {
    let label: String
    let value: Int
}

extension Interval {
    static let sample = Interval(label: "1分", value: 60)
    static let options = [
        Interval(label: "5秒（確認用）", value: 5),
        Interval(label: "1分", value: 60),
        Interval(label: "2分", value: 120),
        Interval(label: "3分", value: 180),
        Interval(label: "5分", value: 300),
        Interval(label: "10分", value: 600),
        Interval(label: "15分", value: 900)
    ]
}
