//
//  LocationTrackingFeature.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/05.
//

import ComposableArchitecture
import CoreLocation
import Shared

@Reducer
struct LocationTrackingFeature{
    
    @ObservableState
    struct State:Equatable{
        let id: String
        var location: FloatLocation?
        var isTracking: Bool
        var isLoading: Bool = false
        var history: [Status] = []
        var selectedInterval: Interval = Interval.sample
        let intervals = Interval.options
        var isLocationPermissionSheetPresented = false
        var shouldRequestLocationPermission = false
        var hasCheckedLocationPermission = false
        var showsUserLocation = false
        
        var isPickerEnabled: Bool {
            !isTracking
        }
    }
    
    @CasePathable
    enum Action:BindableAction, Equatable{
        case onAppear
        case binding(BindingAction<State>)
        case locationPermissionStatusReceived(requiresExplanation: Bool, isAlwaysAuthorized: Bool)
        case locationPermissionProceedTapped
        case locationPermissionSheetDismissed
        case locationPermissionAlwaysAuthorized
        case historyUpdated([Status])
        case dismissTapped
    }
    
    @Dependency(\.locationService) var locationService
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<LocationTrackingFeature> {
        BindingReducer()
        Reduce{state, action in
            switch action{
            case .onAppear:
                guard !state.hasCheckedLocationPermission else { return .none }
                state.hasCheckedLocationPermission = true
                return .run { send in
                    let status = await locationService.authorizationStatus()
                    await send(
                        .locationPermissionStatusReceived(
                            requiresExplanation: status == .notDetermined || status == .authorizedWhenInUse,
                            isAlwaysAuthorized: status == .authorizedAlways
                        )
                    )
                    let initial = await locationService.getLocationHistory()
                    await send(.historyUpdated(initial))
                    // 以降の更新を購読
                    for await history in await locationService.historyStream() {
                        await send(.historyUpdated(history))
                    }
                }
                .cancellable(id: "HistoryStream", cancelInFlight: true)
            case .locationPermissionStatusReceived(let requiresExplanation, let isAlwaysAuthorized):
                state.isLocationPermissionSheetPresented = requiresExplanation
                state.showsUserLocation = isAlwaysAuthorized
                return .none
            case .locationPermissionProceedTapped:
                state.shouldRequestLocationPermission = true
                state.isLocationPermissionSheetPresented = false
                return .none
            case .locationPermissionSheetDismissed:
                guard state.shouldRequestLocationPermission else { return .none }
                state.shouldRequestLocationPermission = false
                return .run { send in
                    await locationService.requestPermission()
                    for _ in 0..<60 {
                        try? await Task.sleep(for: .milliseconds(250))
                        let status = await locationService.authorizationStatus()
                        if status == .authorizedAlways {
                            await send(.locationPermissionAlwaysAuthorized)
                            return
                        }
                        if status == .denied || status == .restricted {
                            return
                        }
                    }
                }
            case .locationPermissionAlwaysAuthorized:
                state.showsUserLocation = true
                return .none
            case .binding(\.isTracking):
                
                return .run{ [
                    id = state.id,
                    isTracking = state.isTracking,
                    interval = state.selectedInterval
                ] send in
                    if(isTracking){
                        await locationService.start(id: id, interval: interval)
                    }else{
                        await locationService.stop(id: id)
                    }
                }
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
